! This module provides several helping routines to handle CLI arguments
! and field data initialization and printing
module helpers

    implicit none
    public

    integer, parameter :: num_args_max = 4

    ! Represents the possible CLI arguments and their values
    type t_arguments
        logical     :: print    = .true.
        integer(4)  :: steps    = 5
        integer(4)  :: width    = 10
        integer(4)  :: height   = 10
        integer(4)  :: threads  = 1
        integer(4)  :: nodes    = 1
    end type

    contains

    ! Parses the CLI arguments into a struct
    subroutine arguments_get(args)
        type(t_arguments), intent(inout) :: args

        integer         :: i, print
        character(16)   :: cmd_buffer

        do i = 1, min(num_args_max, command_argument_count())
            cmd_buffer(:) = " "
            call get_command_argument(i, cmd_buffer)
            select case (i)
                case (1)
                    read(cmd_buffer, *) print
                    args%print = (print .eq. 1)
                case (2)
                    read(cmd_buffer, *) args%steps
                case (3)
                    read(cmd_buffer, *) args%width
                case (4)
                    read(cmd_buffer, *) args%height
                case (5)
                    read(cmd_buffer, *) args%threads
                case (6)
                    read(cmd_buffer, *) args%nodes
            end select 
        end do

        write(*, "(A, I0, A, I0, A, I0, A, I0, A, I0)") "Parameters: Steps=", args%steps, ", Width=", &
            args%width, ", Height=", args%height, ", Threads=", args%threads, ", Nodes=", args%nodes
    end subroutine

    ! Prints the field with the numeric values of each cell
    subroutine field_print_numeric(field, width, height)
        integer(1), dimension(*, *), pointer, intent(in) :: field(:, :)
        integer(4), intent(in) :: width, height

        integer(4)  :: i, j

        do i = 1, width
            do j = 1, height
                write(*, "(I0) ", advance="no") field(j, i)
            end do
            write(*, "(A)") " "
        end do
    end subroutine

    ! Prints a graphical representation of the field
    subroutine field_print_fancy(field, width, height)
        integer(1), dimension(*, *), pointer, intent(in) :: field(:, :)
        integer(4), intent(in) :: width, height

        integer(4)  :: i, j

        do i = 1, width
            do j = 1, height
                if(field(j, i) .eq. 1) then
                    write(*, "(A) ", advance="no") "██"
                else
                    write(*, "(A) ", advance="no") "░░"
                end if
            end do
            write(*, "(A)") " "
        end do
    end subroutine

    ! Fills the field with random ones and zeros
    subroutine field_randomize(field, width, height)
        integer(1), dimension(*, *), pointer, intent(inout) :: field(:, :)
        integer(4), intent(in) :: width, height

        integer(4)  :: i, j
        real        :: rnd

        do i = 1, width
            do j = 1, height
                call random_number(rnd)
                if (rnd .le. 0.5) then
                    field(j, i) = 1
                else
                    field(j, i) = 0
                end if
            end do
        end do
    end subroutine

     ! Fills the field with a glider pattern
    subroutine field_pattern(field)
        integer(1), dimension(*, *), pointer, intent(inout) :: field(:, :)

        field = 0
        field(1:3, 1:3) = reshape((/ 0, 0, 1, 1, 0, 1, 0, 1, 1 /), (/ 3, 3 /))
    end subroutine

    ! Prints a step report
    subroutine print_step_report(args, time, num, field)
        type(t_arguments), intent(in)   :: args
        real(4), intent(in)             :: time
        integer                         :: num
        integer(1), dimension(*, *), pointer, intent(inout) :: field(:, :)

        write(*, "(A, I0, A, F10.6, A)") "Step #", num, " took ", time, " seconds"
        if (args%print) then
            call field_print_fancy(field, args%width, args%height)
            write(*, "(A)") ""
        end if
    end subroutine

    ! Prints the concluding report
    subroutine print_init_report(args, time, field)
        type(t_arguments), intent(in)   :: args
        real(4), intent(in)             :: time
        integer(1), dimension(*, *), pointer, intent(inout) :: field(:, :)

        write(*, "(A, F10.6, A)") "Completed initialization in ", time, " seconds"
        if (args%print) then
            write(*, "(A)") "Initial state"
            call field_print_fancy(field, args%width, args%height)
            write(*, "(A)") " "
        end if
    end subroutine

    ! Prints the concluding report
    subroutine print_report(args, time, name)
        type(t_arguments), intent(in)   :: args
        real(4), intent(in)             :: time
        character(len=*), intent(in)    :: name

        write(*, "(A, I0, A, I0, A, F10.6, A, F10.6, A)") "Done, computed ", args%steps, " steps (each ", &
            (args%width * args%height), " cells) in ", time, " seconds (avg. ", (real(args%steps) / time), " sps)"
        write(*, "(A, A, A, I0, A, I0, A, I0, A, I0, A, F10.6)") "REPORT ", name, " ", args%threads, " ", &
            args%nodes, " ", args%steps, " ", (args%width * args%height), " ", time
    end subroutine

end module