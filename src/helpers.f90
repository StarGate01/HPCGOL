! This module provides several helping routines to handle CLI arguments
! and field data initialization and printing
module helpers

    use, intrinsic :: iso_fortran_env

    implicit none
    public

    integer, parameter :: num_args_max = 6

    ! Represents the possible CLI arguments and their values
    type t_arguments
        logical         :: print    = .true.
        integer(INT32)  :: steps    = 5
        integer(INT32)  :: width    = 10
        integer(INT32)  :: height   = 10
        integer(INT32)  :: threads  = 1
        integer(INT32)  :: nodes    = 1
    end type

    contains

    ! Parses the CLI arguments into a struct
    subroutine arguments_get(args, output)
        type(t_arguments), intent(inout)    :: args
        logical, intent(in)                 :: output

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
        if (output) then
            write(*, "(A, I0, A, I0, A, I0, A, I0, A, I0)") "Parameters: Steps=", args%steps, ", Width=", &
                args%width, ", Height=", args%height, ", Threads=", args%threads, ", Nodes=", args%nodes
        end if
    end subroutine

    ! Prints a graphical representation of the field
    subroutine field_print_fancy(field, width, height)
        integer(INT8), dimension(0:, 0:), intent(in) :: field
        integer(INT32), intent(in) :: width, height

        integer(INT32)  :: i, j

        do j = 1, height
            do i = 1, width
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
        integer(INT8), dimension(0:, 0:), intent(inout) :: field
        integer(INT32), intent(in) :: width, height

        integer(INT32)  :: i, j
        real            :: rnd

        do i = 1, width
            do j = 1, height
                call random_number(rnd)
                if (rnd .le. 0.5) then
                    field(j, i) = 1_INT8
                else
                    field(j, i) = 0_INT8
                end if
            end do
        end do
    end subroutine

     ! Fills the field with a glider pattern
    subroutine field_pattern(field)
        integer(INT8), dimension(0:, 0:), intent(inout) :: field

        field(1:3, 1:3) = reshape((/ 0_INT8, 0_INT8, 1_INT8, 1_INT8, 0_INT8, 1_INT8, 0_INT8, 1_INT8, 1_INT8 /), (/ 3, 3 /))
    end subroutine

    ! Prints a step report
    subroutine print_step_report(args, time, clock, num, field, disable_print_override)
        type(t_arguments), intent(in)   :: args
        real(REAL64), intent(in)        :: time, clock
        integer                         :: num
        integer(INT8), dimension(0:, 0:), intent(in) :: field
        logical, intent(in)            :: disable_print_override

        write(*, "(A, I0, A, I0, A, I0, A, F10.6, A, F10.6, A)") "Step #", num, ", CPU*", args%threads, &
            "T*", args%nodes, "N: ", time, " s, WC: ", clock, " s"
        if (args%print .and. (.not.disable_print_override)) then
            call field_print_fancy(field, args%width, args%height)
            write(*, "(A)") ""
        end if
    end subroutine

    ! Prints the concluding report
    subroutine print_init_report(args, time, clock, field, disable_print_override)
        type(t_arguments), intent(in)   :: args
        real(REAL64), intent(in)        :: time, clock
        integer(INT8), dimension(0:, 0:), intent(in) :: field
        logical, intent(in)             :: disable_print_override

        write(*, "(A, I0, A, I0, A, F10.6, A, F10.6, A)") "Completed initialization, CPU*", args%threads, "T*", &
            args%nodes, "N: ", time, " s, WC: ", clock, " s"
        if (args%print .and. (.not.disable_print_override)) then
            write(*, "(A)") "Initial state"
            call field_print_fancy(field, args%width, args%height)
            write(*, "(A)") " "
        end if
    end subroutine

    ! Prints the concluding report
    subroutine print_report(args, time, clock, name)
        type(t_arguments), intent(in)   :: args
        real(REAL64), intent(in)        :: time, clock
        character(len=*), intent(in)    :: name

        write(*, "(A, I0, A, I0, A, I0, A)") "Done, computed ", args%steps, " steps a ", args%width, &
            " * ", args%height, " cells"
        write(*, "(A, I0, A, I0, A, F10.6, A, F10.6, A)") "Timing: CPU*", args%threads, "T*", &
            args%nodes, "N: ", time, " s, WC: ", clock, " s"
        write(*, "(A, F10.6, A, F10.6, A, F10.6, A)") "Avg: ", (real(args%steps) / clock), " sps, CPU/WC: ", &
            (time / clock), ", parallel efficiency: ", ((time / clock) / real(args%threads * args%nodes)) * 100, "%"
        write(*, "(A, A, A, I0, A, I0, A, I0, A, I0, A, I0, A, F10.6, A, F10.6)") "REPORT ", name, " ", &
            args%threads, " ", args%nodes, " ", args%steps, " ", args%width, " ", args%height, " ", time, " ", clock
    end subroutine

end module