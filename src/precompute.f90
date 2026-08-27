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
        !> Calculates the TF wavevector based on number of electrons
        !> Simpler but often very poor approximation
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

    function precompute_TF_wavevector_fit(epsm1_unpadded, yambo_q, nq_fit) result(q_TF)
        ! Gauss-Newton NLS: minimise sum_i (eps_inv_i - x_i/(x_i+c))^2 over c = q_TF^2.
        ! f(x,c) = x/(x+c),  J_i = df/dc = -x_i/(x_i+c)^2
        ! S'  = -2 * sum((y-f)*J),  S'' ~ 2*sum(J^2)  [Gauss-Newton]
        complex(dp), intent(in) :: epsm1_unpadded(:,:,:)   ! (numYG, numYG, num_q)
        real(dp),    intent(in) :: yambo_q(:,:)             ! (3, num_q)
        integer,     intent(in) :: nq_fit
        real(dp) :: q_TF

        integer,  parameter :: max_iter = 1000
        real(dp), parameter :: tol = 1.0e-8_dp

        integer  :: num_q, i, j, min_idx, n_selected, iter
        real(dp) :: c, c_old, s_prime, s_pprime, f_i, jac_i, x_i, y_i
        real(dp), allocatable :: q_mag2(:), q_mag2_sorted(:), x_fit(:), y_fit(:)
        real(dp) :: current_q_mag2
        integer,  allocatable :: order(:)
        real(dp) :: tmp_mag
        integer  :: tmp_idx

        !> Magnitude and order of q-points
        num_q = size(yambo_q, 2)
        allocate(q_mag2(num_q), order(num_q))
        do i = 1, num_q
            q_mag2(i) = dot_product(yambo_q(:,i), yambo_q(:,i))
            order(i)  = i
        end do

        !> Check input
        if (nq_fit > num_q - 1) then
            print *, "Warning: precompute_TF_wavevector_fit: nq_fit exceeds available non-zero q-points; returning 0"
            q_TF = 0.0_dp
            return
        end if

        !> index-sort - builds a sorted list of q_mag2 and corresponding order, using insertion sort for simplicity
        q_mag2_sorted = q_mag2  
        do i=2, num_q 
            current_q_mag2 = q_mag2_sorted(i)
            !> We check the value to the left of current idx to see if should swap
            j = i - 1
            do while (j >= 1)
                !> We check the value to the left of current idx to see if should swap
                if (q_mag2_sorted(j) <= current_q_mag2) exit 

                !> Else shift the larger value to the right
                q_mag2_sorted(j+1) = q_mag2_sorted(j)
                order(j+1) = order(j) 
                j = j-1
            end do 
            !> Insert the current value into the correct position
            q_mag2_sorted(j+1) = current_q_mag2
            order(j+1) = i
        end do
            
        !> Use i+1 to skip the zero point 
        allocate(x_fit(nq_fit), y_fit(nq_fit))
        do i = 1, nq_fit      
            x_fit(i) = q_mag2_sorted(i+1)
            !> 1 included because "epsm1" is actually X from yambopy
            y_fit(i) = 1 + real(epsm1_unpadded(1, 1, order(i+1)), kind=dp)

            if (x_fit(i) < tiny(1.0_dp)) then
                print *, "Warning: precompute_TF_wavevector_fit: zero-magnitude q-point in fit set; returning 0"
                q_TF = 0.0_dp
                return
            end if

        end do


        ! Initial guess from first point: c = x*(1/y - 1)
        c = x_fit(1) * (1.0_dp / y_fit(1) - 1.0_dp)

        ! Gauss-Newton iterations
        do iter = 1, max_iter
            c_old    = c
            s_prime  = 0.0_dp
            s_pprime = 0.0_dp
            do i = 1, nq_fit
                x_i      = x_fit(i)
                y_i      = y_fit(i)
                f_i      = x_i / (x_i + c)
                jac_i    = -x_i / (x_i + c)**2
                s_prime  = s_prime  - 2.0_dp * (y_i - f_i) * jac_i
                s_pprime = s_pprime + 2.0_dp * jac_i**2
            end do
            c = c - s_prime / s_pprime
            if (abs(c - c_old) < tol) exit
        end do

        if (c <= 0.0_dp) then
            print *, "Warning: precompute_TF_wavevector_fit: fit converged to non-positive q_TF^2; returning 0"
            q_TF = 0.0_dp
            return
        end if

        q_TF = sqrt(c)
    end function precompute_TF_wavevector_fit

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
            error stop
        end if
    end function precompute_zero_G_idx


end module precompute 