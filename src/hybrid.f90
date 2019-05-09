program hybrid

    use MPI
    use helpers
    use functions

    use, intrinsic :: iso_fortran_env

    implicit none

    ! General variables
    type(t_arguments)                                       :: args ! CLI arguments
    integer(INT8), dimension(:, :), allocatable, target     :: field_one, field_two ! Cell data array
    integer(INT8), dimension(:, :), pointer                 :: field_current, field_next ! Cell data pointers
    real(REAL64)                                            :: time_start, time_finish, time_delta, &
                                                                time_sum, clock_delta, clock_sum ! Timing stamps
    integer(INT64)                                          :: clock_start, clock_finish, clock_rate = 0 ! Wallclock

    integer                                                 :: alloc_stat_one, alloc_stat_two ! Cell array allocation status
    integer                                                 :: k ! Step index

    ! Algorithmus specific variables
    integer(INT8)                                           :: cell_sum
    integer(INT32)                                          :: i, j, n, m

    ! Threading specific variables
    integer(INT32)                                          :: t, t_i_begin, t_i_end

    ! MPI specific variables
    integer                                                 :: error, rank
    integer(INT32)                                          :: n_i_begin, n_i_end, n_i_width
    real(REAL64), dimension(1)                              :: time_delta_send, time_delta_recv


    ! Initialize the MPI subsystem
    call mpi_init(error)
    ! Get rank of current node
    call mpi_comm_rank(MPI_COMM_WORLD, rank, error)

    if (rank .eq. 0) then
        write(*, "(A)") "Program: Multi-CPU and Multithreaded optimized"
    end if

    ! Parse CLI arguments
    call arguments_get(args, (rank .eq. 0))

    ! Print work distribution across nodes and threads
    if (rank .eq. 0) then
        write(*, "(A)") "Work distribution:"
        do n = 1, args%nodes
            call compute_work_slice(args%nodes, args%width, n, n_i_begin, n_i_end)
            write(*, "(A, I0, A, I0, A, I0)") "Node #", (n-1), ": col. ", n_i_begin, "-", n_i_end
            do t = 1, args%threads
                call compute_work_slice(args%threads, (n_i_end - n_i_begin + 1), t, t_i_begin, t_i_end)
                write(*, "(A, I0, A, I0, A, I0)") "  Thread #", (t-1), ": col. ", &
                    n_i_begin + t_i_begin - 1, "-", n_i_begin + t_i_end - 1
            end do
        end do
    end if
    
    ! Note that only rank zero does wallclock measuring
    if (rank .eq. 0) then
        write(*, "(A)") "Initializing..."
        call system_clock(clock_start, clock_rate)
    end if
        
    call cpu_time(time_start)

    ! Allocate cell data array
    ! Note that we allocate only a slice of the total memory, as it is spit across nodes
    ! Compute what data each node should work on
    call compute_work_slice(args%nodes, args%width, rank + 1, n_i_begin, n_i_end)
    n_i_width = n_i_end - n_i_begin + 1

    ! Note that we allocate double the memory, this is used to compute the next state while still reading the old
    ! Note that we allocate a border of one cell, this is to capture any outflow
    ! By default, arrays are 1-indexed in fortran, so we use index 0 and n+1
    allocate(field_one(0:args%height + 1, 0:n_i_width + 1), stat = alloc_stat_one)
    if (alloc_stat_one .ne. 0) then
        write(*, "(A, I0, A, I0)") "Error: Cannot allocate field_one memory: ", rank, ", ", alloc_stat_one
        stop 1
    end if
    allocate(field_two(0:args%height + 1, 0:n_i_width + 1), stat = alloc_stat_two)
    if (alloc_stat_two .ne. 0) then
        write(*, "(A, I0, A, I0)") "Error: Cannot allocate field_two memory: ", rank, ", ", alloc_stat_two
        stop 1
    end if

    ! Initialize data
    field_one = 0
    field_two = 0
    field_current => field_one
    field_next => field_two
    ! Initialize cells randomly
    if (rank .eq. 0) then
        write(*, "(A)") "Generating..."
    end if
    ! call field_pattern(field_current)
    call field_randomize(field_current, n_i_width, args%height)
    ! Synchronize nodes and exchange outflow borders
    call mpi_barrier(MPI_COMM_WORLD, error)
    call exchange_borders(rank, args%nodes, field_current, n_i_width, args%height)

    call cpu_time(time_finish)
    if (rank .eq. 0) then
        call system_clock(clock_finish)
        clock_delta = real(clock_finish - clock_start) / real(clock_rate)
    end if
    time_delta = time_finish - time_start
    ! Sum CPU time across all nodes
    time_delta_send(1) = time_delta
    call mpi_reduce(time_delta_send, time_delta_recv, 1, MPI_REAL8, MPI_SUM, 0, MPI_COMM_WORLD, error)
    ! Print initialization diagnostics
    if (rank .eq. 0) then
        call print_init_report(args, time_delta_recv(1), clock_delta, field_current, .true.)
    end if
    if (args%print) then
        ! On MPI systems, we need a special printing function to aggregate the data
        call field_print_fancy_sliced(rank, args%nodes, field_current, n_i_width, args%width, args%height)
    end if

    ! Main computation loop
    do k = 1, args%steps
        ! Insted of copying the previous and next state around,
        ! we simply swap the pointers
        if (mod(k, 2) .eq. 1) then
            field_current => field_one
            field_next => field_two
        else
            field_current => field_two
            field_next => field_one
        end if

        call system_clock(clock_start)
        call cpu_time(time_start)
        
        ! Multithreaded implementation with lookups
        ! We iterate column-wise to exploit CPU cache locality,
        ! because fortran lays out its array memory column-wise.
        !$omp parallel do private(i, j, cell_sum, t, t_i_begin, t_i_end)
        do t = 1, args%threads
            ! Compute what data each thread has to work on
            call compute_work_slice(args%threads, (n_i_end - n_i_begin + 1), t, t_i_begin, t_i_end)
            ! Calculate work scheduled for this thread
            do i = t_i_begin, t_i_end
                do j = 1, args%height
                    ! We sum the 3*3 square around the current cell
                    ! Because we have a outflow border, we do not have to worry about edge cases
                    cell_sum = 0
                    do n = i - 1, i + 1
                        do m = j - 1, j + 1
                            cell_sum = cell_sum + field_current(m, n)
                        end do
                    end do
                    ! Substract center cell, we only want neighbours
                    cell_sum = cell_sum - field_current(j, i)

                    ! We decide on the next state of this cell based on the count of neighbours
                    ! Instead of explicit comparisions, we look up the new state in a lookup table
                    field_next(j, i) = neighbour_lookup(cell_sum, field_current(j, i))
                end do 
            end do
        end do
        !$omp end parallel do
        
        ! Synchronize nodes and exchange outflow borders
        call mpi_barrier(MPI_COMM_WORLD, error)
        call exchange_borders(rank, args%nodes, field_next, n_i_width, args%height)

        call cpu_time(time_finish)
        if (rank .eq. 0) then
            call system_clock(clock_finish)
        end if
        time_delta = time_finish - time_start
        ! Sum CPU time across all nodes
        time_delta_send(1) = time_delta
        call mpi_reduce(time_delta_send, time_delta_recv, 1, MPI_REAL8, MPI_SUM, 0, MPI_COMM_WORLD, error)
        if (rank .eq. 0) then
            time_sum = time_sum + time_delta_recv(1)
            clock_delta = real(clock_finish - clock_start) / real(clock_rate)
            clock_sum = clock_sum + clock_delta
            ! Print step diagnostics
            call print_step_report(args, time_delta_recv(1), clock_delta, k, field_next, .true.)
        end if
        if (args%print) then
             ! On MPI systems, we need a special printing function to aggregate the data
            call field_print_fancy_sliced(rank, args%nodes, field_next, n_i_width, args%width, args%height)
        end if
    end do

    ! Print concluding diagnostics
    if (rank .eq. 0) then
        call print_report(args, time_sum, clock_sum, "hybrid")
    end if
    ! Cleanup
    deallocate(field_one)
    deallocate(field_two)
    call mpi_finalize(error)
end