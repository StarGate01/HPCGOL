program simple

    use helpers

    implicit none

    ! General variables
    type(t_arguments)                                   :: args ! CLI arguments
    integer(1), dimension(:, :), allocatable, target    :: field_one, field_two ! Cell data array
    integer(1), dimension(:, :), pointer                :: field_prev, field_next ! Cell data pointers
    real                                                :: time_start, time_finish, time_delta, time_sum ! Timing stamps

    integer                                             :: alloc_stat_one, alloc_stat_two ! Cell array allocation status
    integer                                             :: k ! Step index

    ! Algorithmus specific variables
    integer(1)                                          :: cell_sum
    integer(4)                                          :: i, j, n, m


    write(*, "(A)") "Program: Simple: NO Vectorisation, NO Multithreading, NO MPI"

    ! Parse CLI arguments
    call arguments_get(args)
  
    write(*, "(A)") "Initializing..."
    call cpu_time(time_start)

    ! Allocate cell data array
    ! Note that we allocate double the memory, this is used to compute the next state while still reading the old
    ! Note that we allocate a border of one cell, this is to capture any outflow
    ! By default, arrays are 1-indexed in fortran, so we use index 0 and n+1
    allocate(field_one(0:args%height + 2, 0:args%width + 2), stat = alloc_stat_one)
    allocate(field_two(0:args%height + 2, 0:args%width + 2), stat = alloc_stat_two)
    if ((alloc_stat_one .ne. 0) .or. (alloc_stat_two .ne. 0)) then
        write(*, "(A, I0, A, I0)") "Error: Cannot allocate field memory: ", alloc_stat_one, ", ", alloc_stat_two
        stop 1
    end if
    field_one = 0
    field_two = 0
    field_prev => field_one
    field_next => field_two
    ! Initialize cells randomly
    ! call field_pattern(field_prev)
    call field_randomize(field_prev, args%width, args%height)

    call cpu_time(time_finish)
    time_delta = time_finish - time_start
    write(*, "(A, F10.6, A)") "Completed initialization in ", time_delta, " seconds"
    if (args%print) then
        write(*, "(A)") "Initial state"
        call field_print_fancy(field_prev, args%width, args%height)
        write(*, "(A)") " "
    end if


    ! Main computation loop
    write(*, "(A, I0, A)") "Computing ", args%steps, " steps..."
    do k = 1, args%steps
        ! Insted of copying the previous and next state around,
        ! we simply swap the pointers
        if (mod(k, 2) .eq. 1) then
            field_prev => field_one
            field_next => field_two
        else
            field_prev => field_two
            field_next => field_one
        end if

        call cpu_time(time_start)
        
        ! Naive implementation
        ! We iterate column-wise to exploit CPU cache locality,
        ! because fortran lays out its array memory column-wise.
        do i = 1, args%width
            do j = 1, args%height
                ! We sum the 3*3 square around the current cell
                ! Because we have a outflow border, we do not have to worry about edge cases
                cell_sum = 0
                do n = i - 1, i + 1
                    do m = j - 1, j + 1
                        cell_sum = cell_sum + field_prev(m, n)
                    end do
                end do
                ! Substract center cell, we only want neighbours
                cell_sum = cell_sum - field_prev(j, i)

                ! We decide on the next state of this cell based on the count of neighbours
                if (field_prev(j, i) .eq. 1) then ! Cell was alive
                    if (cell_sum .lt. 2) then
                        ! Cell dies of loneliness
                        field_next(j, i) = 0
                    else if ((cell_sum .eq. 2) .or. (cell_sum .eq. 3)) then
                        ! Cell is happy
                        field_next(j, i) = 1
                    else
                        ! Cell dies of overpopulation
                        field_next(j, i) = 0
                    end if
                else ! Cell was dead
                    if (cell_sum .eq. 3) then
                        ! Cell is born
                        field_next(j, i) = 1
                    else
                        ! Catch case, transfer state
                        field_next(j, i) = 0
                    end if
                end if
            end do 
        end do

        call cpu_time(time_finish)

        ! Print step diagnostics
        time_delta = time_finish - time_start
        time_sum = time_sum + time_delta
        write(*, "(A, I0, A, F10.6, A)") "Step #", k, " took ", time_delta, " seconds"
        if (args%print) then
            call field_print_fancy(field_next, args%width, args%height)
            write(*, "(A)") ""
        end if
    end do

    ! Print concluding diagnostics
    write(*, "(A, I0, A, I0, A, F10.6, A, F10.6, A)") "Done, computed ", args%steps, " steps (each ", &
        (args%width * args%height), " cells) in ", time_sum, " seconds (avg. ", (time_sum / real(args%steps)), " seconds)"
end