module precompute

    !>      This module handles the computation of lattice properties,
    !>      including the volume, reciprocal lattice vectors, cartesian G-vectors, and
    !>      the Thomas-Fermi wavevector. It also identifies the index of the zero G-vector.


    use precision, only: dp
    implicit none


contains
    !> Compute the cross product of two 3D vectors
    pure function cross(a, b) result(c)
        real(dp), intent(in) :: a(3), b(3)
        real(dp)             :: c(3)

        c(1) = a(2)*b(3) - a(3)*b(2)
        c(2) = a(3)*b(1) - a(1)*b(3)
        c(3) = a(1)*b(2) - a(2)*b(1)
    end function cross


    !> Lattice vectors are stored as columns, so
    !> a1 = lat(:,1)
    function precomputeVol_au3(lat_vecs) result(vol)
        real(dp), intent(in) :: lat_vecs(3,3)
        real(dp) :: vol

        vol = abs( dot_product(lat_vecs(:,1), cross(lat_vecs(:,2), lat_vecs(:,3)))  ) 
    end function precomputeVol_au3

    !> Reciprocal lattice vectors are stored as columns
    function precomputeReciprocalLattice(lat_vecs) result(recip_lat)
        real(dp), intent(in) :: lat_vecs(3,3)
        real(dp) :: recip_lat(3,3)
        real(dp) :: vol
        real(dp) :: a1(3), a2(3), a3(3)
        real(dp), parameter :: two_pi = 6.28318530717958647692_dp

        vol = precomputeVol_au3(lat_vecs)
        a1 = lat_vecs(:,1)
        a2 = lat_vecs(:,2)
        a3 = lat_vecs(:,3)

        recip_lat(:,1) = (two_pi/vol) * cross(a2, a3) 
        recip_lat(:,2) = (two_pi/vol) * cross(a3, a1) 
        recip_lat(:,3) = (two_pi/vol) * cross(a1, a2) 
    end function precomputeReciprocalLattice

    !> Compute cartesian G_vectors from crystal G_vectors
    function precomputeCartesianG(G_vec_crys, recip_lat) result(G_vec_cart)
        !> Input: G_vecs_crys (3, N) - optimized layout
        !> Input: recip_lat (3, 3) - COLUMNS are vectors
        !> Output: G_cart (3, N)
        integer, intent(in) :: G_vec_crys(:, :)
        real(dp), intent(in) :: recip_lat(3,3)
        real(dp) :: G_vec_cart(3, size(G_vec_crys, 2))

        ! G_cart = n1*b1 + n2*b2 + n3*b3
        ! Since b vectors are columns of recip_lat, this is just matrix multiplication.
        ! (3,3) x (3,N) -> (3,N)
        G_vec_cart = matmul(recip_lat, real(G_vec_crys, kind=dp))
    end function precomputeCartesianG

    function precompute_TF_wavevector(num_electrons, volume_au3) result(q_TF)
        integer, intent(in) :: num_electrons
        real(dp), intent(in) :: volume_au3
        real(dp) :: q_TF
        
        ! Constants
        real(dp), parameter :: pi = 3.14159265358979323846_dp
        real(dp) :: density, k_F
    
        ! 1. Safety check for empty system
        if (num_electrons <= 0) then
            q_TF = 0.0_dp
            return
        end if
    
        ! 2. Calculate Electron Density (n = N/V)
        density = real(num_electrons, kind=dp) / volume_au3
    
        ! 3. Calculate Fermi Wavevector (k_F = (3*pi^2*n)^(1/3))
        !    Note: This implicitly handles the conversion from rs
        k_F = (3.0_dp * pi**2 * density)**(1.0_dp / 3.0_dp)
    
        ! 4. Calculate Thomas-Fermi Wavevector (q_TF = sqrt(4*k_F/pi))
        !    In atomic units, a0 = 1, but we can keep it for clarity if defined
        q_TF = sqrt(4.0_dp * k_F / pi)
    
    end function precompute_TF_wavevector

    function precompute_zero_G_idx(G_vec_crys) result(zero_G_idx)
        integer, intent(in)         :: G_vec_crys(:, :)
        integer                     :: zero_G_idx

        integer                     :: i, numG

        zero_G_idx = 0 
        numG = size(G_vec_crys, 2)

        do i = 1, numG
            if (all(G_vec_crys(:, i) == 0)) then
                zero_G_idx = i
                exit
            end if
        end do

        if (zero_G_idx == 0) then
            write(*,*) "Error: Gamma point (0,0,0) not found in G-vector list!"
            stop
        end if
    end function precompute_zero_G_idx


end module precompute 