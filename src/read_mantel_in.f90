module read_mantel_in

    !>      This module is responsible for reading from mantel.in
    !>         
    !>      Separate routines exist for each of wfc2bin, mantel and isoenergy 
    
    use precision,                  only: dp
    use iso_fortran_env,            only: input_unit
    implicit none

    !> &mantel block variables and defaults
    integer                         :: in_min = 1
    integer                         :: in_max = -1
    integer                         :: iq_min = 1
    integer                         :: iq_max = -1
    character(len=16)               :: qtf_method = "fit"
    integer                         :: qtf_fit_nq = 3

    !> &isoenergy block variables and defaults
    integer                         :: numE = 200
    real(dp)                        :: minE = -20.0_dp
    real(dp)                        :: maxE = 20.0_dp
    real(dp)                        :: sigma = 0.2_dp

    !> &qe block variables and defaults
    character(len=32)               ::  qe_kgrid = ""
    integer                         ::  nbnd = 0
    character(len=1024)             ::  wfc_dir = "./WFC"

    !> &wfc2bin block variables and defaults
    integer                         ::  Gmax


contains

    subroutine open_file(unit, filename)
        !> Opens the file, checks it looks ok, and return unit, 
        !> from which can call future reads
        integer, intent(out)        ::  unit 
        character(len=*), intent(in)::  filename 
        integer                     :: ios, filesize 

        if (len_trim(filename) == 0) then 
            !> Could be stdin, or an empty file. If file is empty, it's size is zero
            inquire(unit=input_unit, size=filesize)

            if (filesize <= 0 ) then
                print *, "Error: no input file."
                print *, "Use:  mantel.x < mantel.in    or    mantel.x -i mantel.in"
                print *, "Piped input is not supported."
                error stop "Fatal error opening input file"
            end if 
            unit = input_unit
        
        else
            !> Input was passed in using the mantel.x -i mantel.in format
            open(newunit=unit, file=trim(filename), status='old', action='read', iostat=ios)
            if (ios /= 0) then
                print *, "Error: could not open file, ", trim(filename)
                error stop "Fatal error opening input file"
            end if
        end if
    end subroutine open_file


    subroutine check_namelist(name, iostat)
        !> Checks if the particular &namelist is in the input
        !> iostat = 0 means it is
        !> iostat < 0 means it isn;t, but read was ok - so use defaults
        !> iostat > 0 means file couldn;t be read
        character(len=*), intent(in)    :: name 
        integer, intent(in)             :: iostat 
        
        if (iostat == 0) then
            return 
        endif 

        if (iostat < 0) then 
            print *, "Note: &", trim(name), "not found in input. Using defaults."
            return 
        else 
            print *, "Error: couldn't read namelist group &", trim(name)
            error stop "Fatal error reading input"
        end if 
    end subroutine check_namelist
        
    subroutine read_mantel_namelist(unit)
        !> Reads the mantel namelist 
        integer, intent(in)         ::  unit 
        integer                     ::  ios 
        
        namelist /mantel/ in_min, in_max, iq_min, iq_max, qtf_method, qtf_fit_nq

        rewind(unit)
        read(unit, nml=mantel, iostat=ios)
        call check_namelist("mantel",ios)
        
        if (in_max < in_min) then
            print *, "Error: in_max (", in_max, ") must be >= in_min (", in_min, ")"
            error stop
        end if

        if (in_min < 1) then
            print *, "Error: in_min must be >= 1. Got: ", in_min
            error stop
        end if
    end subroutine read_mantel_namelist


    subroutine read_isoenergy_namelist(unit)
        !> Reads the iosenergy namelist
        integer, intent(in)         ::  unit
        integer                     ::  ios 

        namelist /isoenergy/ numE, minE, maxE, sigma

        rewind(unit)
        read(unit, nml=isoenergy, iostat=ios)
        call check_namelist("isoenergy",ios)
    
        !> Validate inputs
        if (numE <= 0) then
            print *, "Error: number of energy points must be positive" 
            error stop
        end if 

        if (minE > maxE) then
            print *, "Error: minE is greater than maxE"
            error stop 
        end if 

        if (sigma <=0) then
            print *, "Error: sigma is not positive. Require non-zero smearing"
            error stop 
        end if 
    end subroutine read_isoenergy_namelist


    subroutine read_qe_namelist(unit)
        !> Reads the qe namelist
        integer, intent(in)         ::  unit
        integer                     ::  ios 

        namelist /qe/ qe_kgrid, nbnd, wfc_dir

        rewind(unit)
        read(unit, nml=qe, iostat=ios)
        call check_namelist("qe",ios)
    
    end subroutine read_qe_namelist


    subroutine read_wfc2bin_namelist(unit)
        !> Reads the mantel namelist 
        integer, intent(in)         ::  unit 
        integer                     ::  ios 
        
        namelist /wfc2bin/ Gmax

        rewind(unit)
        read(unit, nml=wfc2bin, iostat=ios)
        call check_namelist("wfc2bin",ios)
        
        if (Gmax <= 0) then
            print *, "Error: Gmax (", Gmax, ") must be a positive integer"
            error stop
        end if
    end subroutine read_wfc2bin_namelist





end module read_mantel_in