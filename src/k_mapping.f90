module k_mapping

    !>          This module handles the mapping of k+q vectors back
    !>          into the first Brillouin zone, and finding the closest
    !>          k-point in the original list. 

    use precision,           only: dp
    implicit none


    contains

    subroutine batch_map_k_via_frac(&
        k_plus_q_batch, &                   ! 3, numK_in _batch
        recip_lattice, &                    ! 3,3. vectors as columns
        cart_kpoints, &                     ! 3, numK_total
        best_k_vecs, &                      ! 3, numK_in_batch
        best_indices, &
        found_mask, &
        tol &
        )
        real(dp), intent(in)        :: k_plus_q_batch(:,:)          ! k + q 
        real(dp), intent(in)        :: recip_lattice(3,3)       
        real(dp), intent(in)        :: cart_kpoints(:, :)       
        real(dp), intent(out)       :: best_k_vecs(:, :)            ! mapped k_vec, \tilde{k}
        integer, intent(out)        :: best_indices(:)              
        logical, intent(out)        :: found_mask(:)
        real(dp), intent(in), optional :: tol
        
        !> local variables
        real(dp)                    :: inv_recip_lattice(3,3)   
        real(dp), allocatable       :: frac_kpoints(:,:)
        integer                     :: numK_in_batch, numK         !If one batch, same size
        real(dp)                    :: tolerance, tol2, min_dist_sq, dist_sq
        integer                     :: ik, ikp, best_idx
        real(dp)                    :: k_plus_q_frac(3)
        real(dp)                    :: diff_frac(3), diff_cart(3)


        numK_in_batch = size(k_plus_q_batch, 2)
        numK = size(cart_kpoints, 2)

        !> Set tolerance
        tolerance = 2.0e-3_dp
        if (present(tol)) then
            tolerance = tol
        end if
        tol2 = tolerance ** 2

        !> Invert reciprocal lattice
        call invert_3x3(recip_lattice, inv_recip_lattice)

        !> Convert cartesian k-points to fractional
        allocate(frac_kpoints(3, numK))
        frac_kpoints = matmul(inv_recip_lattice, cart_kpoints)

        !$omp parallel do default(shared) private(ikp,ik,k_plus_q_frac,diff_frac,diff_cart,dist_sq,min_dist_sq,best_idx)
        do ikp = 1, numK_in_batch
            k_plus_q_frac = matmul(inv_recip_lattice, k_plus_q_batch(:, ikp))

            !>initialise
            min_dist_sq = huge(1.0_dp)
            best_idx = 1

            do ik = 1, numK
                diff_frac = k_plus_q_frac - frac_kpoints(:, ik)

                !> Apply periodic boundary conditions in fractional space
                diff_frac = diff_frac - anint(diff_frac)

                diff_cart = matmul(recip_lattice, diff_frac)

                dist_sq  = dot_product(diff_cart, diff_cart)

                if (dist_sq < min_dist_sq) then
                    min_dist_sq = dist_sq
                    best_idx = ik
                end if
            end do 

            best_indices(ikp) = best_idx
            best_k_vecs(:, ikp) = cart_kpoints(:, best_idx)

            if (min_dist_sq < tol2) then
                found_mask(ikp) = .true.
            else
                found_mask(ikp) = .false.
            end if

        end do
        !$omp end parallel do
        deallocate(frac_kpoints)
    end subroutine batch_map_k_via_frac






    !> Helper: Fast analytic inversion of a 3x3 matrix
    !> Standard Cramer's rule, much faster than LU decomposition for N=3
    pure subroutine invert_3x3(A, Ainv)
        real(dp), intent(in) :: A(3,3)
        real(dp), intent(out) :: Ainv(3,3)
        real(dp) :: det, inv_det

        ! Compute determinant
        det = A(1,1)*(A(2,2)*A(3,3) - A(3,2)*A(2,3)) &
            - A(1,2)*(A(2,1)*A(3,3) - A(3,1)*A(2,3)) &
            + A(1,3)*(A(2,1)*A(3,2) - A(3,1)*A(2,2))

        if (abs(det) < 1.0e-12_dp) then
            ! Handle singularity if necessary, or just set to zero
            Ainv = 0.0_dp
            return 
        end if

        inv_det = 1.0_dp / det

        ! Compute inverse using cofactors
        Ainv(1,1) = (A(2,2)*A(3,3) - A(3,2)*A(2,3)) * inv_det
        Ainv(2,1) = (A(3,1)*A(2,3) - A(2,1)*A(3,3)) * inv_det
        Ainv(3,1) = (A(2,1)*A(3,2) - A(3,1)*A(2,2)) * inv_det

        Ainv(1,2) = (A(3,2)*A(1,3) - A(1,2)*A(3,3)) * inv_det
        Ainv(2,2) = (A(1,1)*A(3,3) - A(3,1)*A(1,3)) * inv_det
        Ainv(3,2) = (A(3,1)*A(1,2) - A(1,1)*A(3,2)) * inv_det

        Ainv(1,3) = (A(1,2)*A(2,3) - A(2,2)*A(1,3)) * inv_det
        Ainv(2,3) = (A(2,1)*A(1,3) - A(1,1)*A(2,3)) * inv_det
        Ainv(3,3) = (A(1,1)*A(2,2) - A(2,1)*A(1,2)) * inv_det
    end subroutine invert_3x3

end module k_mapping