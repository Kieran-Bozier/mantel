module read_mantel_nml
    !> This module is responsible for reading in the mantel.nml file 

    use precision,                  only: dp
    implicit none
    
    !> &structure block variables
    real(dp)                        :: alat=0.0_dp
    real(dp)                        :: volume=0.0_dp
    real(dp)                        :: cell_a1_au(3)
    real(dp)                        :: cell_a2_au(3)
    real(dp)                        :: cell_a3_au(3)

    !> &system
    character(len=20)               ::  prefix=""
    integer                         ::  nelec=0
    real(dp)                        ::  scf_fermi=0.0_dp

contains

    subroutine open_nml(unit)
        !> mantel.nml always has a fixed name in the working directory,
        !> so unlike the .mantel.in there is no filename to pass in
        integer, intent(out)        ::  unit
        integer                     ::  ios

        open(newunit=unit, file="mantel.nml", status='old', action='read', iostat=ios)
        if (ios /= 0) then
            print *, "Error: could not open mantel.nml"
            print *, "Run mantel-xml.py on the QE xml files to generate it."
            error stop "Fatal error opening mantel.nml"
        end if
    end subroutine open_nml  


    subroutine check_nml_namelist(name, iostat)
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
    end subroutine check_nml_namelist

    subroutine read_structure_namelist(unit)
        !> Reads the mantel namelist 
        integer, intent(in)         ::  unit 
        integer                     ::  ios 

        namelist /structure/ alat, volume, cell_a1_au, cell_a2_au, cell_a3_au

        rewind(unit)
        read(unit, nml=structure, iostat=ios)
        call check_nml_namelist("structure",ios)
        
        if (volume <= 0) then
            print *, "Error: volume is non-positive"
            error stop 
        end if 
    end subroutine read_structure_namelist


    subroutine read_system_namelist(unit)
        !> Reads the mantel namelist 
        integer, intent(in)         ::  unit 
        integer                     ::  ios 

        namelist /system/ prefix, nelec, scf_fermi

        rewind(unit)
        read(unit, nml=system, iostat=ios)
        call check_nml_namelist("system",ios)
        
        if (nelec <= 0) then
            print *, "Error: Number of electrons is non-positive"
            error stop 
        end if 
    end subroutine read_system_namelist


end module read_mantel_nml