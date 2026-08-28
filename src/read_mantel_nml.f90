module read_mantel_nml
    !> This module is responsible for reading in the .nml file 

    use precision,                  only: dp
    use iso_fortran_env,            only: input_unit
    implicit none
    
    !> &structure block variables
    real(dp)                        :: alat=0
    real(dp)                        :: volume=0
    real(dp)                        :: cell_a1_au(3)
    real(dp)                        :: cell_a2_au(3)
    real(dp)                        :: cell_a3_au(3)

    !> &system
    integer                         ::  nelec
    real(dp)                        ::  scf_fermi 

    



end module read_mantel_nml