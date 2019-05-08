program simple

    use helpers

    implicit none

    ! General variables
    type(t_arguments)                                   :: args ! CLI arguments
    integer(1), dimension(:, :), allocatable, target    :: field_one, field_two ! Cell data array
    integer(1), dimension(:, :), pointer                :: field_current, field_temp ! Cell data pointers
    real                                                :: time_start, time_finish, time_delta, time_sum ! Timing stamps

    integer                                             :: alloc_stat_one, alloc_stat_two ! Cell array allocation status
    integer                                             :: k ! Step index

    ! Algorithmus specific variables
    integer(1)                                          :: cell_sum
    integer(1), dimension(0:8, 0:1), parameter          :: neighbour_lookup = reshape(&
        (/  0, 0, 0, 1, 0, 0, 0, 0, 0, &
            0, 0, 1, 1, 0, 0, 0, 0, 0 /), (/ 9, 2 /))
    integer(4)                                          :: i, j


    write(*, "(A)") "Program: Simple optimized further: Vectorized sums using SIMD"

    ! Parse CLI arguments
    call arguments_get(args)
  
    write(*, "(A)") "Initializing..."
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
    field_one = 0
    field_two = 0
    field_current => field_one
    field_temp => field_two

    ! Initialize cells randomly
    ! call field_pattern(field_current)
    call field_randomize(field_current, args%width, args%height)

    call cpu_time(time_finish)
    time_delta = time_finish - time_start
    ! Print initialization diagnostics
    call print_init_report(args, time_delta, field_current)


    ! Main computation loop
    write(*, "(A, I0, A)") "Computing ", args%steps, " steps..."
    do k = 1, args%steps
        ! We donst swap around anymore, we use the other field for intermediate storage
        call cpu_time(time_start)
        
        ! Naive implementation with lookup and row sums
        ! We sum three colums next to each other row-wise and store them
        ! This loop can be vectorized using SIMD
        do i = 1, args%width
            field_temp(:, i) = sum(field_current(:, i-1:i+1), dim=2)
        end do

        ! We iterate column-wise to exploit CPU cache locality,
        ! because fortran lays out its array memory column-wise.
        do i = 1, args%width
            do j = 1, args%height
                ! Because we have a outflow border, we do not have to worry about edge cases
                ! Substract center cell, we only want neighbours
                ! We now only have to sum 3 elements in the current column, further reducing cache misses
                ! Also, this summation can be vectorized using SIMD
                cell_sum = sum(field_temp(j-1:j+1, i), dim=1) - field_current(j, i)

                ! We decide on the next state of this cell based on the count of neighbours
                ! Instead of explicit comparisions, we look up the new state in a lookup table
                ! Note that we write back to teh same field
                field_current(j, i) = neighbour_lookup(cell_sum, field_current(j, i))
            end do 
        end do

        call cpu_time(time_finish)

        ! Print step diagnostics
        time_delta = time_finish - time_start
        time_sum = time_sum + time_delta
        call print_step_report(args, time_delta, k, field_current)
    end do

    ! Print concluding diagnostics
    call print_report(args, time_sum, "simple_simd")
end