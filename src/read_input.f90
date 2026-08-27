module read_input

    !>      This module is responsible for handling the reading of the read file
    !>      and passing the variables back to the main script
    
    use precision,                  only: dp
    use iso_fortran_env,            only: input_unit
    implicit none

    !> Global variables to be read from the input file
    character(len=1024)             :: wfc_dir="./WFC"
    integer                         :: num_electrons=0
    integer                         :: in_min=1, in_max=-1
    integer                         :: iq_min = 1, iq_max = -1
    character(len=16)               :: qtf_method = "fit"
    integer                         :: qtf_fit_nq = 3

    !> Dummy variables to absorb &qe keys that mantel.x doesn't use
    character(len=64)               :: qe_kgrid
    integer                         :: nbnd

    !> Namelist groups
    namelist /qe/ wfc_dir, qe_kgrid, nbnd
    namelist /mantel/ num_electrons, in_min, in_max, iq_min, iq_max, qtf_method, qtf_fit_nq


contains
    subroutine read_stdin()
        !> Reads input from standard input
        !> Note: piped input (cat mantel.in | mantel.x) is not supported

        integer                     :: iostat

        !> Read &qe block
        rewind(input_unit)
        read(input_unit, nml=qe, iostat=iostat)
        if (iostat /= 0) then
            print *, "Error: Failed to read &qe namelist from standard input."
            print *, "Make sure you are running: mantel.x < input_file > output_file"
            error stop
        end if

        !> Read &mantel block
        rewind(input_unit)
        read(input_unit, nml=mantel, iostat=iostat)
        if (iostat /= 0) then
            print *, "Error: Failed to read &mantel namelist from standard input."
            print *, "Make sure you are running: mantel.x < input_file > output_file"
            error stop
        end if

        !> Validate inputs 
        if (trim(qtf_method) == 'electrons') then
            if (num_electrons <= 0) then
                print *, "Error: qtf_method = 'electrons' requires num_electrons > 0. Got: ", num_electrons
                error stop
            end if
        end if
        
        if (in_max < in_min) then
            print *, "Error: in_max (", in_max, ") must be >= in_min (", in_min, ")"
            error stop
        end if

        if (in_min < 1) then
            print *, "Error: in_min must be >= 1. Got: ", in_min
            error stop
        end if

    end subroutine read_stdin


    subroutine read_lattice_vectors(lattice_vectors_bohr)
        !> Returns a 3x3 matrix with columns as lattice vectors in bohr
        real(dp), intent(out)           ::  lattice_vectors_bohr(3,3)
        character(len=256)              ::  line, line_upper
        integer                         ::  i, iostat
        logical                         ::  found
        real(dp)                        ::  scale_factor

        !> constants
        real(dp), parameter             ::  bohr_to_angstrom = 0.52917721092_dp
        real(dp), parameter             ::  angstrom_to_bohr = 1.0_dp / bohr_to_angstrom

        found = .false.
        scale_factor = 1.0_dp

        !> Rewind input unit to read from the beginning
        rewind(input_unit)

        !> -----------------------------------------------------------
        !> PHASE 1: SEARCH
        !> -----------------------------------------------------------
        do 
            read(input_unit, '(A)', iostat=iostat) line
            if (iostat /= 0) exit  ! End of file, stop searching

            !> Convert line to uppercase for case-insensitive comparison
            line_upper = line
            call to_upper(line_upper)

            if (index(line_upper, "CELL_PARAMETERS") > 0) then
                found = .true.
                
                !> Check for units
                if (index(line_upper, "ANGSTROM") > 0) then
                    scale_factor = angstrom_to_bohr
                else if (index(line_upper, "BOHR") > 0) then
                    scale_factor = 1.0_dp
                else 
                    print *, "  -> No unit specified. Assuming Bohr (a.u.)"
                end if
                
                !> We found it! Exit the search loop.
                !> The file pointer is now positioned at the start of the NEXT line.
                exit            
            end if
        end do

        !> -----------------------------------------------------------
        !> PHASE 2: VALIDATE AND READ
        !> -----------------------------------------------------------
        if (.not. found) then
            print *, "Error: CELL_PARAMETERS not found in input."
            error stop
        end if

        !> Read in the actual vectors (Now we are outside the search loop)
        do i = 1, 3
            read(input_unit, *) lattice_vectors_bohr(1, i), &
                                lattice_vectors_bohr(2, i), &
                                lattice_vectors_bohr(3, i)
        end do

        !> Convert Units
        lattice_vectors_bohr = lattice_vectors_bohr * scale_factor

    end subroutine read_lattice_vectors



    ! Helper to handle case-insensitivity
    subroutine to_upper(str)
        character(len=*), intent(inout) :: str
        integer :: i, ic
        do i = 1, len_trim(str)
            ic = iachar(str(i:i))
            if (ic >= 97 .and. ic <= 122) then
                str(i:i) = achar(ic - 32)
            end if
        end do
    end subroutine to_upper

end module read_input