! This module deduplicates some functions
module functions

    use MPI
    use helpers

    use, intrinsic :: iso_fortran_env

    implicit none

    ! The cell state lookup table
    integer(INT8), dimension(0:8, 0:1), parameter :: neighbour_lookup = reshape(&
        (/  0_INT8, 0_INT8, 0_INT8, 1_INT8, 0_INT8, 0_INT8, 0_INT8, 0_INT8, 0_INT8, &
            0_INT8, 0_INT8, 1_INT8, 1_INT8, 0_INT8, 0_INT8, 0_INT8, 0_INT8, 0_INT8 /), (/ 9, 2 /))

    contains

    ! This subroutine distributes work across threads
    subroutine compute_work_slice(slots, width, t, begin, end)
        integer(INT32), intent(in)  :: slots, width, t
        integer(INT32), intent(out) :: begin, end
        integer(INT32)              :: size, size_rest

        ! Compute how much each thread has to work
        size = width / slots
        size_rest = mod(width, slots)
        ! Compute what data each thread has to work on
        begin = ((t - 1) * size) + 1
        end = t * size
        ! Distribute the rest of work by adding one column if needed
        if(t .le. size_rest) then
            begin = begin + (t - 1)
            end = end + (t - 1) + 1
        else
            begin = begin + size_rest
            end = end + size_rest
        end if
    end

    ! This subroutine synchronizes the outflow borders between nodes
    subroutine exchange_borders(rank, nodes, field, width, height)
        integer(INT32), intent(in)  :: rank, nodes, width, height
        integer(INT8), dimension(0:, 0:), intent(inout) :: field

        integer, dimension(MPI_STATUS_SIZE) :: status
        integer                             :: error

        ! Two-phase data exchange: First every node sends its rightmost column to the right,
        ! and stores the incoming data in its left border. Then, its performs the same thing but
        ! in the other direction (data left out, border right in)
        if (nodes .gt. 1) then
            if(rank .eq. 0) then
                ! Node zero sends to the right
                call mpi_send(field(:, width), height + 2, MPI_INTEGER1, rank + 1, 0, MPI_COMM_WORLD, error)
                ! Node zero receives from the right
                call mpi_recv(field(:, width + 1),  height + 2, MPI_INTEGER1, rank + 1, 0, MPI_COMM_WORLD, status, error)
            else if (rank .eq. (nodes - 1)) then
                ! Last node receives from the left
                call mpi_recv(field(:, 0),  height + 2, MPI_INTEGER1, rank - 1, 0, MPI_COMM_WORLD, status, error)
                ! Last mode sends to the left
                call mpi_send(field(:, 1),  height + 2, MPI_INTEGER1, rank - 1, 0, MPI_COMM_WORLD, error)
            else
                ! Middle nodes send to the right and simultaniously receive from the left
                call mpi_sendrecv(field(:, width),  height + 2, MPI_INTEGER1, rank + 1, 0, &
                    field(:, 0),  height + 2, MPI_INTEGER1, rank - 1, 0, MPI_COMM_WORLD, status, error)
                ! Middle nodes send to the left and simultaniously receive from the right
                call mpi_sendrecv(field(:, 1),  height + 2, MPI_INTEGER1, rank - 1, 0, &
                    field(:, width + 1),  height + 2, MPI_INTEGER1, rank + 1, 0, MPI_COMM_WORLD, status, error)
            end if
        end if
    end subroutine

    ! This subroutine collects all field slices from all nodes into node zero and then prints it
    ! Note that this should only bne used for small fields due to memory limitations
    subroutine field_print_fancy_sliced(rank, nodes, field, slice_width, width, height)
        integer(INT32), intent(in)  :: rank, nodes, slice_width, width, height
        integer(INT8), dimension(0:, 0:), intent(in) :: field

        integer(INT8), dimension(:, :), allocatable :: temp_field
        integer, dimension(MPI_STATUS_SIZE)     :: status
        integer                                 :: error, n, alloc_stat
        integer(INT32)                          :: n_i_begin, n_i_end

        ! Allocate a temp field
        if(rank .eq. 0) then
            allocate(temp_field(0:height + 1, 0:width + 1), stat = alloc_stat)
            if (alloc_stat .ne. 0) then
                write(*, "(A, I0)") "Error: Cannot allocate temp_field memory: ", alloc_stat
                stop 1
            end if
            ! Copy the first slice
            temp_field = 1
            temp_field(:, 1:slice_width) = field(:, 1:slice_width)
        end if
        ! Wait for allocation
        call mpi_barrier(MPI_COMM_WORLD, error)

        ! Aggregate all data slices into node zero
        do n = 1, nodes - 1
            if (rank .eq. n) then
                ! All other nodes send their local data
                call mpi_send(field(:, 1:slice_width), (height + 2) * slice_width, &
                    MPI_INTEGER1, 0, 0, MPI_COMM_WORLD, error)
            else if (rank .eq. 0) then
                ! Node zero computes where to put it and stores the received data
                call compute_work_slice(nodes, width, n + 1, n_i_begin, n_i_end)
                call mpi_recv(temp_field(:, n_i_begin:n_i_end), (height + 2) * (n_i_end - n_i_begin + 1), &
                    MPI_INTEGER1, n, 0, MPI_COMM_WORLD, status, error)
            end if
        end do
        ! Wait for aggregation
        call mpi_barrier(MPI_COMM_WORLD, error)

        ! Print and free the temp field
        if(rank .eq. 0) then
            call field_print_fancy(temp_field, width, height)
            write(*, "(A)") ""
            deallocate(temp_field)
        end if
    end subroutine
    
end module