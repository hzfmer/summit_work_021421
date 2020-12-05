! author: william savran
! date: 03.02.2015
! this parallelization asks for one processor per depth layer. this is a 1d decomposition where 
! NX = nx, NY = ny, NZ = 1

program add
  implicit none
  include 'mpif.h'
  
  ! Variable declarations
  ! ***********************************
  real, parameter               :: std = 0.05
  integer(kind=8), parameter    :: nx = 9000, ny = 6750
  integer(kind=8), parameter    :: nz_ssh = 500, nz_tap = 375
  integer(kind=8), parameter    :: nrec_len_hom = nx*ny*3, nrec_len_fr = nx*ny, nrec_len_het = nx*ny*3
  integer(MPI_OFFSET_KIND)      :: offset_hom, offset_fr, offset_het
  integer                       :: rank, nthreads
  integer                       :: err
  integer                       :: MCW, fh1, fh2, fh3
  real, dimension(:), allocatable :: buf_fr
  real, dimension(:), allocatable :: buf_hom, buf_het
  real                          :: temp_vp, temp_vs, temp_rho, a, ss, sp
  real                          :: temp_qp, temp_qs, temp_xi, temp_yi, temp_zi
  integer(kind=8)               :: i, j, k, ind
  character(len=50)             :: filename_fr, filename_hom, filename_het
  real                          :: tapval
  real, parameter               :: vpmax = 9500, vsmax = 6717.
  integer                       :: comm_fr
  integer                       :: color
  
  filename_fr = 'ssh_large_20m_dm.out'
  filename_hom = 'la_habra_large.media'
  filename_het = 'la_habra_large_hetdm.media'
    
  call MPI_INIT(err)
  call MPI_COMM_DUP(MPI_COMM_WORLD,MCW,err)
  call MPI_COMM_RANK(MCW,rank,err)
  call MPI_COMM_SIZE(MCW,nthreads,err)

  allocate (buf_fr(nx*ny), buf_hom(nx*ny*3), buf_het(nx*ny*3))

  ! compute offset based on rank
  offset_fr = rank*nrec_len_fr*4
  offset_hom  = rank*nrec_len_hom*4
  offset_het = rank*nrec_len_het*4
  k = rank+1

  if (k.le.nz_tap) then
    tapval = 1.0
  elseif (k.gt.nz_ssh) then
    tapval = 0.
  else
    tapval = 1. - real(k - nz_tap) / real(nz_ssh - nz_tap)
  endif
  write(*,*) 'k, tapval:', k, tapval
  
  ! define new communicator for those processes that will read the fractal file
  if (k.le.nz_ssh) then
      color = 1
  else
      color = MPI_UNDEFINED
  endif
  call MPI_Comm_split(MCW, color, rank, comm_fr, err)
  call error_check(err, "creating new commuicator")

  ! open fractal model
  if (k.le.nz_ssh) then
     call MPI_FILE_OPEN(comm_fr, filename_fr, MPI_MODE_RDONLY, MPI_INFO_NULL, fh1, err)
     call error_check(err, "opening fractal model")
     call MPI_FILE_READ_AT_ALL(fh1, offset_fr, buf_fr, nrec_len_fr, MPI_REAL, MPI_STATUS_IGNORE, err)
     call error_check(err, "reading fractal model")
     call MPI_FILE_CLOSE(fh1, err)
  endif
  call MPI_Barrier(MPI_COMM_WORLD, err)
  if (rank == 0) write(*,*) 'Done reading fractal file.'
  
  ! open homogeneous mesh
  call MPI_FILE_OPEN(MCW, filename_hom, MPI_MODE_RDONLY, MPI_INFO_NULL, fh2, err)
  call error_check(err, "opening homogeneous model")
  write(*,*) 'offset_hom=', offset_hom
  call MPI_FILE_READ_AT_ALL(fh2, offset_hom, buf_hom, nrec_len_hom, MPI_REAL, MPI_STATUS_IGNORE, err)
  call error_check(err, "reading homogeneous model")
  call MPI_FILE_CLOSE(fh2, err)
  
  ! loop through slice
  do j=1,ny
    do i=1,nx
      ! ordered vp(1), vs(1), rho(1)
      ind = (j-1)*nx+i
      temp_vp = buf_hom(3*(ind-1)+1)
      temp_vs = buf_hom(3*(ind-1)+2)
      temp_rho = buf_hom(3*(ind-1)+3)
      ! convert to slowness
      sp = 1./temp_vp
      ss = 1./temp_vs
      ! add heterogeneities
      if (k.lt.nz_ssh) then
        sp = sp*(1-std*buf_fr(ind)*tapval)
        ss = ss*(1-std*buf_fr(ind)*tapval)
      endif
      ! convert back
      buf_het(3*(ind-1)+1)=1./sp
      if (buf_het(3*(ind-1)+1) .gt. vpmax) then
         buf_het(3*(ind-1)+1) = vpmax
      endif
      buf_het(3*(ind-1)+2)=1./ss
      if (buf_het(3*(ind-1)+2) .gt. vsmax) then
         buf_het(3*(ind-1)+2) = vsmax
      endif
      if (k.lt.nz_ssh) then
         buf_het(3*(ind-1)+3) = temp_rho*(1+std*buf_fr(ind)*tapval)
      else
         buf_het(3*(ind-1)+3) = temp_rho
      endif
  ! Get number of threads
    enddo
  enddo
  
  ! open complete file
  call MPI_FILE_OPEN(MCW, filename_het, MPI_MODE_WRONLY + MPI_MODE_CREATE, MPI_INFO_NULL, fh3, err)
  call error_check(err, "opening heterogeneous model")
  call MPI_FILE_WRITE_AT_ALL(fh3, offset_het, buf_het, nrec_len_het, MPI_REAL, MPI_STATUS_IGNORE, err)
  call error_check(err, "writing heterogeneous model")
  call MPI_FILE_CLOSE(fh3, err)
  
  ! open combined model
  call MPI_FINALIZE(err)
end program

subroutine error_check(err, message)
  integer :: err, ierr, errlen
  character (len=*) :: message
  character (len=500) :: errmsg

  if (err .ne. 0) then
     call MPI_Error_string(err, errmsg, errlen, ierr)  
     write(*,*) 'Error', err, 'in ', message, ':'
     write(*,*) errmsg
  endif
  return
end
