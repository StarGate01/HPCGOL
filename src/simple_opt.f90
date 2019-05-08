program simple_opt

    use helpers

    use, intrinsic :: iso_fortran_env

    implicit none

    ! General variables
    type(t_arguments)                                       :: args ! CLI arguments
    integer(INT8), dimension(:, :), allocatable, target     :: field_one, field_two ! Cell data array
    integer(INT8), dimension(:, :), pointer                 :: field_current, field_next ! Cell data pointers
    real(REAL64)                                            :: time_start, time_finish, time_delta, time_sum, clock_delta, clock_sum ! Timing stamps
    integer(INT64)                                          :: clock_start, clock_finish, clock_rate ! Wallclock

    integer                                                 :: alloc_stat_one, alloc_stat_two ! Cell array allocation status
    integer                                                 :: k ! Step index

    ! Algorithmus specific variables
    integer(INT8)                                           :: cell_sum
    integer(INT8), dimension(0:8, 0:1), parameter           :: neighbour_lookup = reshape(&
        (/  0, 0, 0, 1, 0, 0, 0, 0, 0, &
            0, 0, 1, 1, 0, 0, 0, 0, 0 /), (/ 9, 2 /))
    integer(INT32)                                          :: i, j, n, m


    write(*, "(A)") "Program: Simple optimized: Lookup table"

    ! Parse CLI arguments
    call arguments_get(args, .true.)
  
    write(*, "(A)") "Initializing..."
    call system_clock(clock_start, clock_rate)
    call cpu_time(time_start)

    ! Allocate cell data array
    ! Note that we allocate double the memory, this is used to compute the next state while still reading the old
    ! Note that we allocate a border of one cell, this is to capture any outflow
    ! By default, arrays are 1-indexed in fortran, so we use index 0 and n+1
    allocate(field_one(0:args%height + 2, 0:args%width + 2), stat = alloc_stat_one)
    if (alloc_stat_one .ne. 0) then
        write(*, "(A, I0)") "Error: Cannot allocate field_one memory: ", alloc_stat_one
        stop 1
    end if
    allocate(field_two(0:args%height + 2, 0:args%width + 2), stat = alloc_stat_two)
    if (alloc_stat_two .ne. 0) then
        write(*, "(A, I0)") "Error: Cannot allocate field_two memory: ", alloc_stat_two
        stop 1
    end if
    
    ! Initialize data
    field_one = 0
    field_two = 0
    field_current => field_one
    field_next => field_two
    ! Initialize cells randomly
    write(*, "(A)") "Generating..."
    ! call field_pattern(field_current)
    call field_randomize(field_current, args%width, args%height)

    call cpu_time(time_finish)
    call system_clock(clock_finish)
    time_delta = time_finish - time_start
    clock_delta = real(clock_finish - clock_start) / real(clock_rate)
    ! Print initialization diagnostics
    call print_init_report(args, time_delta, clock_delta, field_current)


    ! Main computation loop
    write(*, "(A, I0, A)") "Computing ", args%steps, " steps..."
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
        
        ! Naive implementation with lookups
        ! We iterate column-wise to exploit CPU cache locality,
        ! because fortran lays out its array memory column-wise.
        do i = 1, args%width
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

        call cpu_time(time_finish)
        call system_clock(clock_finish)
        time_delta = time_finish - time_start
        time_sum = time_sum + time_delta
        clock_delta = real(clock_finish - clock_start) / real(clock_rate)
        clock_sum = clock_sum + clock_delta
        ! Print step diagnostics
        call print_step_report(args, time_delta, clock_delta, k, field_next)
    end do

    ! Print concluding diagnostics
    call print_report(args, time_sum, clock_sum, "simple_opt")
    deallocate(field_one)
    deallocate(field_two)
end