module g_mapping

    !>      This module handles mapping from a 3D double grid to 
    !>      the 1D vectors of length numG
    
    use precision,          only: dp 
    implicit none
contains
    subroutine double_g_mapping(G_vec_crys, double_fft_grid_size, g_map_i, g_map_j, g_map_k)
        !> Finds the mapping. Works with arrays in standard FTT format
        !> with [0,0,0] at 0,0,0
        integer, intent(in)             ::      G_vec_crys(:,:)
        integer, intent(in)             ::      double_fft_grid_size(3)
        integer, intent(out)            ::      g_map_i(:)
        integer, intent(out)            ::      g_map_j(:)
        integer, intent(out)            ::      g_map_k(:)

        integer                         ::      numG, Nx, Ny, Nz, n
        integer                         ::      h, k, l

        numG = size(G_vec_crys, 2)
        Nx = double_fft_grid_size(1)
        Ny = double_fft_grid_size(2)
        Nz = double_fft_grid_size(3)

        do n = 1, numG 
            h = G_vec_crys(1, n)
            k = G_vec_crys(2, n)
            l = G_vec_crys(3, n)

            g_map_i(n) = modulo(h, Nx) + 1
            g_map_j(n) = modulo(k, Ny) + 1
            g_map_k(n) = modulo(l, Nz) + 1
        end do 

    end subroutine double_g_mapping

end module g_mapping