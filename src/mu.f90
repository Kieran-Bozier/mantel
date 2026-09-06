    module mu_module 
    use precision,              only: dp, ic 
    use read_mantel_in,         only: in_min, in_max, iq_min, iq_max
    
    implicit none
contains 
    subroutine linspace(min, max, num, arr)
        !> Fortran version of linspace
        real(dp), intent(in)        :: min
        real(dp), intent(in)        :: max
        integer, intent(in)         :: num
        real(dp), intent(out)       :: arr(num)
        
        real(dp)                    :: delta
        integer                     :: i

        if (num <= 0) then
            print *, "Number of elements must be positive"
            error stop
        end if

        if (min > max) then
            print *, "min value greater than max value"
            error stop
        end if

        if (num < 2) then
            print *, "Less than two elements - not enough points for array"
            error stop
        end if 

        delta = ((max) - (min)) / (num - 1)

        do i = 1, num
            arr(i) = min + (i-1)*delta
        end do
    end subroutine linspace

    subroutine write_mu_table(unit, sigma_values, gauss_nef, gauss_nef_Ry, &
        W_00, mu_values, mu_rescaled, nef, scf_fermi)
        !> Writes the mu(sigma) table to an already-open unit. Shared by
        !> write_mu_dat and the stdout summary so the two cannot drift apart.
        integer, intent(in)             :: unit
        real(dp), intent(in)            :: sigma_values(:)
        real(dp), intent(in)            :: gauss_nef(:), gauss_nef_Ry(:)
        real(dp), intent(in)            :: W_00(:), mu_values(:), mu_rescaled(:)
        real(dp), intent(in)            :: nef, scf_fermi

        integer                         :: numSigma, i

        numSigma = size(sigma_values)

        if (size(gauss_nef)   /= numSigma .or. size(gauss_nef_Ry) /= numSigma .or. &
        size(W_00)        /= numSigma .or. size(mu_values)    /= numSigma .or. &
        size(mu_rescaled) /= numSigma) then
        print *, "Error: columns passed to write_mu_table have inconsistent lengths"
        error stop "Fatal error writing mu.dat"
        end if

        write(unit, '("# mu(sigma) from mantel")')
        write(unit, '("# Fermi energy [eV] = ", F12.6)') scf_fermi
        write(unit, '("# Bands  in_min = ", I0, "  in_max = ", I0)') in_min, in_max
        write(unit, '("# Q-pts  iq_min = ", I0, "  iq_max = ", I0)') iq_min, iq_max
        if (nef > 0.0_dp) then
        write(unit, '("# External N_F = ", F12.6, " states/Ry/spin")') nef
        else
        write(unit, '("# No external N_F supplied - mu rescaled column set to -1")')
        end if
        write(unit, '("#", A13, 2X, A20, 2X, A20, 2X, A14, 2X, A10, 2X, A14)') &
        "sigma (eV)", "N_F (states/eV/spin)", "N_F (states/Ry/spin)", &
        "W(0,0) (eV)", "mu", "mu (dos rescaled)"

        do i = 1, numSigma
        write(unit, '(2X, F12.4, 2X, F20.6, 2X, F20.6, 2X, F14.6, 2X, F10.6, 2X, F14.6)') &
        sigma_values(i), gauss_nef(i), gauss_nef_Ry(i), &
        W_00(i), mu_values(i), mu_rescaled(i)
        end do

    end subroutine write_mu_table


    subroutine write_mu_dat(filename, sigma_values, gauss_nef, gauss_nef_Ry, &
        W_00, mu_values, mu_rescaled, nef, scf_fermi)
        !> Writes mu.dat
        character(len=*), intent(in)    :: filename
        real(dp), intent(in)            :: sigma_values(:)
        real(dp), intent(in)            :: gauss_nef(:), gauss_nef_Ry(:)
        real(dp), intent(in)            :: W_00(:), mu_values(:), mu_rescaled(:)
        real(dp), intent(in)            :: nef, scf_fermi

        integer                         :: out_unit, ios
        character(len=256)              :: msg

        open(newunit=out_unit, file=trim(filename), status='replace', &
        action='write', iostat=ios, iomsg=msg)
        if (ios /= 0) then
        print *, "Error: could not open ", trim(filename)
        print *, "System message: ", trim(msg)
        error stop "Fatal error writing mu.dat"
        end if

        call write_mu_table(out_unit, sigma_values, gauss_nef, gauss_nef_Ry, &
                W_00, mu_values, mu_rescaled, nef, scf_fermi)

        close(out_unit)
    end subroutine write_mu_dat

end module mu_module


program mu 
    use precision,                  only: dp, ic 
    use array_io,                   only: load_array, save_array 
    use mu_module,                  only: linspace, write_mu_dat, write_mu_table 
    use read_mantel_in,             only: open_file, read_mantel_namelist, read_mu_namelist, &
                                            in_min, in_max, iq_min, iq_max, min_sigma, max_sigma, num_sigma, nef
    use read_mantel_nml,            only: open_nml, read_system_namelist, scf_fermi
    use iso_fortran_env,            only: output_unit
implicit none

    real(dp),parameter                  ::  pi = 4.0_dp * atan(1.0_dp)
    real(dp),parameter                  ::  Ha_to_eV = 27.211386_dp
    real(dp),parameter                  ::  tolerance = 1.0e-5_dp


    integer                             ::  mantel_in_unit, mantel_nml_unit 
    real(dp),allocatable                ::  band_energies(:,:)   ! (nbnd, numK) because of transpose in mantel_xml
    real(dp),allocatable                ::  q_weights(:) 
    real(dp)                            ::  wq
    integer                             ::  numBands, numK

    !> sigma values
    real(dp), allocatable               ::  sigma_values(:)

    !> gaussian array
    real(dp),allocatable                ::  gaussian_array(:,:,:)   ! (numSigma, numBands, numK)

    real(dp),allocatable                ::  gauss_nef(:)
    real(dp),allocatable                ::  W_00(:)
    real(dp),allocatable                ::  mu_num(:), mu_values(:)
    complex(dp),allocatable             ::  W_iq(:,:,:)
    integer(ic),allocatable             ::  ikp_arr(:)
    character(len=20)                   ::  filename
    real(dp),allocatable                ::  A(:,:), B(:,:), T(:,:), Wk(:,:)


    integer                             ::  ik, i_n, i_band, i_sigma, iq

    real(dp),parameter                  ::  Ry_to_eV = 13.6057039763_dp
    real(dp),allocatable                ::  mu_rescaled(:), gauss_nef_Ry(:)
    real(dp)                            ::  nef_eV


    !> Load all the variables from .mantel.in and .mantel.nml
    call open_file(mantel_in_unit, "")
    call read_mantel_namelist(mantel_in_unit)
    call read_mu_namelist(mantel_in_unit)

    call open_nml(mantel_nml_unit)
    call read_system_namelist(mantel_nml_unit)
    close(mantel_nml_unit)


    !> Load band energies, q_weights 
    call load_array("band_energies.bin", band_energies)
    call load_array("q_weights.bin", q_weights)

    if (size(band_energies,1) < in_max) then
        print *, "Error: in_max is out of bounds of band_energies"
        error stop
    end if

    !> Build sigma array
    allocate(sigma_values(num_sigma))
    call linspace(min_sigma, max_sigma, num_sigma, sigma_values)

    !> Build Gaussian array
    !> Care needed that in general QE nbnd /= numBands
    numK = size(band_energies, 2)
    numBands = in_max - in_min + 1
    allocate(gaussian_array(num_sigma , numBands, numK))

    !> Build gaussian array, value is contribution to Nf from Gaussian centred on each k,n
    do ik = 1, numK
        do i_n = 1, numBands
            !> Need offset to index band_energies
            i_band = in_min + i_n - 1 
            do i_sigma = 1, num_sigma
                gaussian_array(i_sigma, i_n, ik) = (1 / (sigma_values(i_sigma) * sqrt(pi))) &
                &* exp( - ( ( band_energies(i_band, ik) - scf_fermi) )**2 / (sigma_values(i_sigma)**2))
            end do 
        end do 
    end do     

    !> Obtain Nf as function of smearing
    allocate(gauss_nef(num_sigma))
    gauss_nef = 0.0_dp 

    do ik = 1, numK
        do i_n = 1, numBands
            gauss_nef(:) = gauss_nef(:) + gaussian_array(:, i_n, ik)
        end do 
    end do 
    gauss_nef = gauss_nef / numK

    !> Checks on q
    if (iq_max == -1) iq_max = size(q_weights)
    if (iq_max > size(q_weights)) then
        print *, "Error: iq_max (", iq_max, ") exceeds the number of q points (", size(q_weights), ")"
        error stop
    end if

    if (iq_min < 1 .or. iq_min > iq_max) then
        print *, "Error: iq_min (", iq_min, ") must lie between 1 and iq_max (", iq_max, ")"
        error stop
    end if


    allocate(A(num_sigma, numBands))
    allocate(B(num_sigma, numBands))
    allocate(T(num_sigma, numBands))
    allocate(Wk(numBands, numBands))
    allocate(mu_num(num_sigma))
    mu_num = 0.0_dp


    do iq = iq_min, iq_max 
        write(filename, '("W_iq", I0, ".bin")') iq
        call load_array(filename, W_iq)

        !> Check
        if (size(W_iq, 1) /= numBands) then
            print *, "Error: mismatch in the dimensions of W_iq and the number of bands"
            error stop
        end if 

        if (size(W_iq, 3) /= numK) then 
            print *, "Error: mismatch in band_energies and W dimensions (num kpoints)"
            error stop 
        end if 

        write(filename, '("ikp_iq", I0, ".bin")') iq
        call load_array(filename, ikp_arr)
        wq = q_weights(iq) / sum(q_weights)

        if (size(ikp_arr) /= numK) then
            print *, "Error: mismatch in band_energies and ikp dimensions (num kpoints)"
            error stop
        end if

        do ik = 1, numK
            if (ikp_arr(ik) < 1 .or. ikp_arr(ik) > numK) then
                print *, "Error: ikp_arr index out of range at ik =", ik, ", value =", ikp_arr(ik)
                error stop
            end if

            A  = gaussian_array(:,:,ik)
            B  = gaussian_array(:,:,ikp_arr(ik))
            Wk = real(W_iq(:,:,ik))

            !> T = A Wk, shape (num_sigma, numBands)
            call dgemm('N','N', num_sigma, numBands, numBands, 1.0_dp, A, num_sigma, &
                        Wk, numBands, 0.0_dp, T, num_sigma)

            mu_num = mu_num + wq * sum(T * B, dim=2)
        end do
    end do

    !> Hartree -> eV, and the one surviving factor of 1/Nk
    mu_num = mu_num * Ha_to_eV / numK

       !> W(0,0) has both DOS factors divided out; mu keeps one.
      !> Guard once on N_F so the two can never disagree about which
      !> sigma values are trustworthy.
    allocate(W_00(num_sigma))
    allocate(mu_values(num_sigma))
    do i_sigma = 1, num_sigma
        if (gauss_nef(i_sigma) < tolerance) then
            W_00(i_sigma)      = 0.0_dp
            mu_values(i_sigma) = 0.0_dp
        else
            W_00(i_sigma)      = mu_num(i_sigma) / gauss_nef(i_sigma)**2
            mu_values(i_sigma) = mu_num(i_sigma) / gauss_nef(i_sigma)
        end if
    end do

    !> N_F in states/Ry/spin, for comparison against lambda.x
    allocate(gauss_nef_Ry(num_sigma))
    gauss_nef_Ry = gauss_nef * Ry_to_eV

    !> Rescaling: keep W(0,0) from this calculation, but take N_F from an
    !> external (e.g. tetrahedra) DOS rather than the Gaussian one.
    !> nef is supplied in states/Ry/spin to match the lambda.x convention.
    allocate(mu_rescaled(num_sigma))
    if (nef > 0.0_dp) then
        nef_eV       = nef / Ry_to_eV
        mu_rescaled  = W_00 * nef_eV
    else
        !> Sentinel: no external N_F supplied
        mu_rescaled = -1.0_dp
    end if


    call write_mu_dat("mu.dat", sigma_values, gauss_nef, gauss_nef_Ry, &
    W_00, mu_values, mu_rescaled, nef, scf_fermi)
    call write_mu_table(output_unit, sigma_values, gauss_nef, gauss_nef_Ry, &
      W_00, mu_values, mu_rescaled, nef, scf_fermi)


end program mu 