! This module deduplicates some functions used by threads, nodes and hybrid
module functions

    use MPI

    use, intrinsic :: iso_fortran_env

    implicit none

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
        integer(INT8), dimension(*, *), pointer, intent(inout) :: field(:, :)

        integer, dimension(MPI_STATUS_SIZE) :: status
        integer                             :: error

        ! Two-phase data exchange: First every node sends its rightmost column to the right,
        ! and stores the incoming data in its left border. Then, its performs the same thing but
        ! in the other direction (data left out, border right in)
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
    end subroutine
    
end module