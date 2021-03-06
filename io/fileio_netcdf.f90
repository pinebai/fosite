!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: fileio_netcdf.f90                                                 #
!#                                                                           #
!# Copyright (C) 2008-2012                                                   #
!# Tobias Illenseer <tillense@astrophysik.uni-kiel.de>                       #
!# Manuel Jung <mjung@astrophysik.uni-kiel.de>                               #
!#                                                                           #
!# This program is free software; you can redistribute it and/or modify      #
!# it under the terms of the GNU General Public License as published by      #
!# the Free Software Foundation; either version 2 of the License, or (at     #
!# your option) any later version.                                           #
!#                                                                           #
!# This program is distributed in the hope that it will be useful, but       #
!# WITHOUT ANY WARRANTY; without even the implied warranty of                #
!# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, GOOD TITLE or        #
!# NON INFRINGEMENT.  See the GNU General Public License for more            #
!# details.                                                                  #
!#                                                                           #
!# You should have received a copy of the GNU General Public License         #
!# along with this program; if not, write to the Free Software               #
!# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.                 #
!#                                                                           #
!#############################################################################
!----------------------------------------------------------------------------!
!> \author Björn Sperling
!!
!! \brief I/O for NetCDF files 
!!
!! \extends fileio_gnuplot
!! \ingroup fileio
!----------------------------------------------------------------------------!
MODULE fileio_netcdf
#ifdef HAVE_NETCDF
  USE netcdf
#endif
#ifdef PARALLEL
#ifdef HAVE_MPI_MOD
  USE mpi
#endif
#endif
  USE fileio_gnuplot
  USE geometry_common, ONLY : Geometry_TYP, GetName, GetType
  USE geometry_generic, ONLY : Convert2Cartesian
  USE mesh_common, ONLY : Mesh_TYP
  USE physics_common, ONLY : Physics_TYP, GetName, GetType
  USE timedisc_common, ONLY : Timedisc_TYP
  USE common_dict
  IMPLICIT NONE
#ifdef PARALLEL
#ifdef HAVE_MPIF_H
  INCLUDE 'mpif.h'
#endif
#endif
  !--------------------------------------------------------------------------!
  PRIVATE
  INTEGER :: DEFAULT_NF90_REAL                     !< default real data type
  !> names for dimensions and variables 
  CHARACTER(LEN=*), PARAMETER :: IDIM_NAME="inum"  
  CHARACTER(LEN=*), PARAMETER :: JDIM_NAME="jnum"  
  CHARACTER(LEN=*), PARAMETER :: CNUM_NAME="cnum"  
  CHARACTER(LEN=*), PARAMETER :: VSIZE_NAME="vsize"
  CHARACTER(LEN=*), PARAMETER :: CVSIZE_NAME="cvsize" 
  CHARACTER(LEN=*), PARAMETER :: POSITIONS_NAME ="bary_centers"
  CHARACTER(LEN=*), PARAMETER :: CPOSITIONS_NAME ="corners"
  CHARACTER(LEN=*), PARAMETER :: TIME_NAME="time"
  CHARACTER(LEN=*), PARAMETER :: PHYSICS_NAME="physics"
  CHARACTER(LEN=*), PARAMETER :: GEOMETRY_NAME="geometry"
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       ! types
       FileIO_TYP, &
       ! constants
#ifdef HAVE_NETCDF
       NF90_NOCLOBBER, NF90_SHARE, NF90_64BIT_OFFSET, &
#ifdef HAVE_HDF5
       NF90_FORMAT_CLASSIC, NF90_FORMAT_64BIT, &
       NF90_FORMAT_NETCDF4, NF90_FORMAT_NETCDF4_CLASSIC, &
       NF90_CLASSIC_MODEL, NF90_NETCDF4, NF90_HDF5, &
#endif
#endif
       ! methods
       InitFileio_netcdf, &
#ifdef HAVE_NETCDF
       OpenFile_netcdf, &
       CloseFile_netcdf, &
       WriteHeader_netcdf, &
       ReadHeader_netcdf, &
       WriteTimestamp_netcdf, &
       ReadTimestamp_netcdf, &
       WriteDataset_netcdf, &
       ReadDataset_netcdf, &
#endif
       CloseFileio_netcdf
  !--------------------------------------------------------------------------!

CONTAINS
  !> \public Constructor for the netcdf file I/O 
  !!
  !! Initilizes the file I/O type, filename, stoptime, number of outputs, 
  !! number of files, unit number, config as a dict
  SUBROUTINE InitFileio_netcdf(this,Mesh,Physics,fmt,fpath,filename,stoptime,dtwall,&
       count,fcycles,ncfmt,unit)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this          !< \param [in,out] this fileio type
    TYPE(Mesh_TYP)    :: Mesh          !< \param [in] Mesh mesh type
    TYPE(Physics_TYP) :: Physics       !< \param [in] Physics Physics type
    INTEGER           :: fmt           !< \param [in] fmt fileio type number
    CHARACTER(LEN=*)  :: fpath         !< \param [in] fpath
    CHARACTER(LEN=*)  :: filename      !< \param [in] filename
    REAL              :: stoptime      !< \param [in] stoptime
    INTEGER           :: dtwall        !< \param [in] dtwall wall clock time
    INTEGER           :: count         !< \param [in] count number of outputs
    INTEGER           :: fcycles       !< \param [in] fcycles file cycle number
    INTEGER           :: ncfmt         !< \param [in] ncfmt netcdf format
    INTEGER, OPTIONAL :: unit          !< \param [in] unit fileio unit number
    !------------------------------------------------------------------------!
    REAL              :: dummy
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics,fmt,fpath,filename,stoptime,count,fcycles,ncfmt,unit
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!
    CALL InitFileIO(this,Mesh,Physics,fmt,"NetCDF",fpath,filename,"nc",stoptime,&
         dtwall,count,fcycles,.FALSE.,unit)
#ifdef HAVE_NETCDF
#ifdef PARALLEL
#ifdef HAVE_HDF5
    IF (ncfmt.NE.NF90_NETCDF4) &
#endif
         CALL Error(this,"InitFileIO","NetCDF: parallel file format must be NF90_NETCDF4")
#endif
    this%ncfmt = ncfmt
    ! determine the default netCDF data type for real numbers
    SELECT CASE (SELECTED_REAL_KIND(PRECISION(dummy)))
    CASE(4)
       DEFAULT_NF90_REAL = NF90_REAL4
    CASE(8)
       DEFAULT_NF90_REAL = NF90_REAL8
    CASE DEFAULT
       CALL Warning(this,"InitfileIO_netcdf","Cannot determine default NetCDF real types.")
    END SELECT
    IF ((Mesh%INUM.EQ.1).OR.(Mesh%JNUM.EQ.1)) THEN
       ! 1D case
       this%rank = 1
    ELSE
       ! 2D case
       this%rank = 2
    END IF
#else
       CALL Error(this,"InitFileIO","NetCDF support disabled")
#endif
  END SUBROUTINE InitFileIO_netcdf

#ifdef HAVE_NETCDF
  !> \public Specific routine to open a file for netcdf I/O
  !!
  SUBROUTINE OpenFile_netcdf(this,action)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this    !< \param [in,out] this fileio type
    INTEGER          :: action  !< \param [in] action mode of file access
    !------------------------------------------------------------------------!
    INTENT(IN)       :: action
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    SELECT CASE(action)
    CASE(READONLY,READEND)
#ifdef PARALLEL
       this%error = nf90_open(GetFilename(this),NF90_NOWRITE,this%ncid,&
                              comm=MPI_COMM_WORLD,info=MPI_INFO_NULL)
#else
       this%error = nf90_open(GetFilename(this),NF90_NOWRITE,this%ncid)
#endif
    CASE(REPLACE)
#ifdef PARALLEL
       this%error = nf90_create(GetFilename(this),this%ncfmt,this%ncid,&
                                comm=MPI_COMM_WORLD,info=MPI_INFO_NULL)
#else
       this%error = nf90_create(GetFilename(this),this%ncfmt,this%ncid)
#endif
    CASE(APPEND)
#ifdef PARALLEL
       this%error = nf90_open(GetFilename(this),NF90_WRITE,this%ncid,&
                              comm=MPI_COMM_WORLD,info=MPI_INFO_NULL)
#else
       this%error = nf90_open(GetFilename(this),NF90_WRITE,this%ncid)
#endif
    CASE DEFAULT
       CALL Error(this,"OpenFile_netcdf","Unknown access mode.")
    END SELECT
    IF (this%error.NE.NF90_NOERR) CALL Error(this,"OpenFile_netcdf",&
         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE OpenFile_netcdf

  !> \public Closes the file I/O
  !!
  SUBROUTINE CloseFile_netcdf(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this   !< \param [in,out] this fileio type
    !------------------------------------------------------------------------!
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    this%error = nf90_close(this%ncid)
    IF (this%error.NE.NF90_NOERR) CALL Error(this,"CloseFile_netcdf",&
         TRIM(nf90_strerror(this%error)))    
  END SUBROUTINE CloseFile_netcdf

  !> \public Writes the file header
  !!
  SUBROUTINE WriteHeader_netcdf(this,Mesh,Physics)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this     !< \param [in,out] this fileio type
    TYPE(Mesh_TYP)    :: Mesh     !< \param [in] mesh mesh type
    TYPE(Physics_TYP) :: Physics  !< \param [in] physics physics type
    !------------------------------------------------------------------------!
    CHARACTER(LEN=8)  :: series_attr
    INTEGER           :: k
    INTEGER           :: posid,timeid,varid,physid,geoid,cposid
    INTEGER           :: vsize
    INTEGER, PARAMETER:: cnum = 4
    INTEGER, DIMENSION(:), POINTER :: posdims, vardims, cposdims
    INTEGER, DIMENSION(1), TARGET :: dims1D, timedims
    INTEGER, DIMENSION(2), TARGET :: dims2D
    INTEGER, DIMENSION(3), TARGET :: dims3D
    INTEGER, DIMENSION(4), TARGET :: dims4D
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!
    IF (this%cycles.EQ.0) THEN
       ! time series in one file
       IF (this%rank.EQ.1) THEN
          ! 1D case
          ! save positions as a 1D column vector -> 2D array
          posdims => dims2D
          cposdims => dims4D ! allways 4D array
          vsize = 1
          ! save variables as a 2D array, last dimension accounts for time dependence 
          vardims => dims2D
       ELSE
          ! 2D case
          ! save positions as a 2D vector for each grid point -> 3D array
          posdims => dims3D
          cposdims => dims4D
          vsize = 2
          ! variables are scalar 2D data with time dependence -> 3D array
          vardims => dims3D
       END IF
       series_attr = ", series"
    ELSE
       ! each time step in a single file
       IF (this%rank.EQ.1) THEN
          ! 1D case
          ! save positions as a 1D column vector -> 2D array
          posdims => dims2D
          cposdims => dims4D ! allways 4D array
          vsize = 1
          ! save variables as a 1D array, no time dependence -> 1D array
          vardims => dims1D
       ELSE
          ! 2D case
          ! save positions as a 2D vector for each grid point -> 3D array
          posdims => dims3D
          cposdims => dims4D
          vsize = 2
          ! variables are scalar 2D data without time dependence -> 2D array
          vardims => dims2D
       END IF
       series_attr = ""
    END IF
          
    this%error = NF90_NOERR

    ! define global attributes for physics, i.e. advection problem, and geometry
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_put_att(this%ncid,NF90_GLOBAL,PHYSICS_NAME,GetType(Physics))
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_put_att(this%ncid,NF90_GLOBAL,GEOMETRY_NAME,GetType(Mesh%geometry))

    ! define dimensions and variable for time stamps
    IF (this%cycles.EQ.0) THEN
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_def_dim(this%ncid,TIME_NAME,NF90_UNLIMITED, &
                                      timedims(1))
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_def_var(this%ncid,TIME_NAME,DEFAULT_NF90_REAL, &
                                      timedims(1),timeid)
    ELSE
       ! just a scalar variable for one time stamp
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_def_var(this%ncid,TIME_NAME,DEFAULT_NF90_REAL, &
                                      timeid)       
    END IF
    ! define dimensions and variables for bary center positions
    IF ((this%error.EQ.NF90_NOERR).AND.(Mesh%INUM.GT.1)) &
         this%error = nf90_def_dim(this%ncid,IDIM_NAME,Mesh%INUM,&
                                   posdims(1)) ! <- maybe overwritten by next command
    IF ((this%error.EQ.NF90_NOERR).AND.(Mesh%JNUM.GT.1)) &
         this%error = nf90_def_dim(this%ncid,JDIM_NAME,Mesh%JNUM,&
                                   posdims(this%rank))
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_def_dim(this%ncid,VSIZE_NAME,vsize,&
                                   posdims(this%rank+1))
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_def_var(this%ncid,POSITIONS_NAME,DEFAULT_NF90_REAL, &
                                   posdims,posid)
    ! define dimensions and variables for corner positions
    IF ((this%error.EQ.NF90_NOERR).AND.(Mesh%INUM.EQ.1)) THEN
         this%error = nf90_def_dim(this%ncid,IDIM_NAME,1, &
                                   cposdims(1))
    ELSE
        cposdims(1) = posdims(1)
    END IF
    IF ((this%error.EQ.NF90_NOERR).AND.(Mesh%JNUM.EQ.1)) THEN
         this%error = nf90_def_dim(this%ncid,JDIM_NAME,1, &
                                   cposdims(2))
    ELSE
        cposdims(2) = posdims(this%rank)
    END IF
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_def_dim(this%ncid,CNUM_NAME,cnum,&
                                   cposdims(3))
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_def_dim(this%ncid,CVSIZE_NAME,2,&
                                    cposdims(4))

    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_def_var(this%ncid,CPOSITIONS_NAME,DEFAULT_NF90_REAL, &
                                   cposdims,cposid)
    ! define attributes for computational domain extent
    IF (Mesh%INUM.GT.1) THEN
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,posid,"xmin",Mesh%xmin)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,posid,"xmax",Mesh%xmax)
    END IF
    IF (Mesh%JNUM.GT.1) THEN
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,posid,"ymin",Mesh%ymin)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,posid,"ymax",Mesh%ymax)
    END IF
    
    ! rearrange vardims array (identical to posdims)
    DO k=1,this%rank
       vardims(k) = posdims(k)
    END DO
    ! change last dimension to account for time dependence
    IF (this%cycles.EQ.0) THEN
        vardims(this%rank+1) = timedims(1)
    END IF

    ! define variables for simulation data (primitive variables)
    DO k=1,Physics%VNUM
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_def_var(this%ncid,TRIM(Physics%pvarname(k)), &
                         DEFAULT_NF90_REAL,vardims,varid)
       ! assign attributes for OpenDX data fields
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,varid,"field",&
                         TRIM(Physics%pvarname(k)) // ", scalar" // series_attr)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,varid,"positions",&
                         POSITIONS_NAME)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_att(this%ncid,varid,"cpositions",&
                         CPOSITIONS_NAME)
    END DO
    
    ! finish variable definition
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_enddef(this%ncid)
    ! in NetCDF positions are only written once, hence it is done here
    IF (this%error.EQ.NF90_NOERR) CALL WritePositions_netcdf(this,Mesh,posid)
    IF (this%error.EQ.NF90_NOERR) CALL WriteCPositions_netcdf(this,Mesh,cposid)
    IF (this%error.NE.NF90_NOERR) CALL Error(this,"WriteHeader_netcdf",&
         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE WriteHeader_netcdf

  !> \public Reads the file header
  !!
  SUBROUTINE ReadHeader_netcdf(this,Mesh,Physics,success)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this     !< \param [in,out] this fileio type
    TYPE(Mesh_TYP)    :: Mesh     !< \param [in] mesh mesh type
    TYPE(Physics_TYP) :: Physics  !< \param [in] physics physics type
    LOGICAL           :: success  !< \param [out] success 
    !------------------------------------------------------------------------!
    INTEGER           :: dimid,posid
    INTEGER           :: check_phys,check_geo,check_inum,check_jnum
    REAL              :: check_xmin,check_xmax,check_ymin,check_ymax
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics
    INTENT(OUT)       :: success
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!
    success = .TRUE.
    ! read physics and geometry
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_get_att(this%ncid,NF90_GLOBAL,PHYSICS_NAME,check_phys)
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_get_att(this%ncid,NF90_GLOBAL,GEOMETRY_NAME,check_geo)
    ! read mesh resolution and extent
    IF (this%error.EQ.NF90_NOERR) THEN
       ! x-dimension
       this%error = nf90_inq_dimid(this%ncid,IDIM_NAME,dimid)
       IF (this%error.EQ.NF90_NOERR) THEN
          this%error = nf90_inquire_dimension(this%ncid,dimid,len=check_inum)
       ELSE IF (this%error.EQ.NF90_EBADDIM) THEN
          ! maybe 1D
          check_inum = 1
          this%error = NF90_NOERR
       END IF
       ! y-dimension
       this%error = nf90_inq_dimid(this%ncid,JDIM_NAME,dimid)
       IF (this%error.EQ.NF90_NOERR) THEN
          this%error = nf90_inquire_dimension(this%ncid,dimid,len=check_jnum)
       ELSE IF (this%error.EQ.NF90_EBADDIM) THEN
          ! maybe 1D
          check_jnum = 1
          this%error = NF90_NOERR
       END IF
    END IF
    ! read extent of computational domain
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_inq_varid(this%ncid,POSITIONS_NAME,posid)
    IF (check_inum.GT.1) THEN
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_get_att(this%ncid,posid,"xmin",check_xmin)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_get_att(this%ncid,posid,"xmax",check_xmax)
    END IF
    IF (check_inum.GT.1) THEN
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_get_att(this%ncid,posid,"ymin",check_ymin)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_get_att(this%ncid,posid,"ymax",check_ymax)
    END IF
    
    ! check values
    IF (check_phys.NE.GetType(Physics)) THEN
       CALL Warning(this,"ReadHeader_netcdf","physics mismatch")
       success = .FALSE.
    END IF
    IF (check_geo.NE.GetType(Mesh%Geometry)) THEN
       CALL Warning(this,"ReadHeader_netcdf","geometry mismatch")
       success = .FALSE.
    END IF
    IF ((check_inum.NE.Mesh%INUM).OR.(check_jnum.NE.Mesh%JNUM)) THEN
       CALL Warning(this,"ReadHeader_netcdf","resolution mismatch")
       success = .FALSE.
    END IF
    IF ((check_xmin.NE.Mesh%xmin).OR.(check_xmax.NE.Mesh%xmax).OR. &
        (check_ymin.NE.Mesh%ymin).OR.(check_ymax.NE.Mesh%ymax)) THEN
       CALL Warning(this,"ReadHeader_netcdf","computational domain mismatch")
       success = .FALSE.
    END IF
    ! general read failure
    IF (this%error.NE.NF90_NOERR) THEN
       CALL Warning(this,"ReadHeader_netcdf",TRIM(nf90_strerror(this%error)))
       success = .FALSE.
    END IF
  END SUBROUTINE ReadHeader_netcdf


  SUBROUTINE WritePositions_netcdf(this,Mesh,posid)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    TYPE(Mesh_TYP)   :: Mesh
    INTEGER          :: posid
    !------------------------------------------------------------------------!
    INTEGER, DIMENSION(this%rank+1) :: start, num
    !------------------------------------------------------------------------!
    INTENT(IN)       :: Mesh,posid
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    IF (Mesh%JNUM.EQ.1) THEN
       ! 1D x-direction
       num(:)   = (/ Mesh%IMAX-Mesh%IMIN+1, 1 /)
       start(:) = (/ Mesh%IMIN, 1 /)
       this%error = nf90_put_var(this%ncid,posid,&
            Mesh%bcenter(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN,1), &
            start=start,count=num)
    ELSE IF (Mesh%INUM.EQ.1) THEN
       ! 1D y-direction
       num(:)   = (/ Mesh%JMAX-Mesh%JMIN+1, 1 /)
       start(:) = (/ Mesh%JMIN, 1 /)
       this%error = nf90_put_var(this%ncid,posid,&
            Mesh%bcenter(Mesh%IMIN,Mesh%JMIN:Mesh%JMAX,2), &
            start=start,count=num)
    ELSE
       ! 2D
       num(:)    = (/ Mesh%IMAX-Mesh%IMIN+1, Mesh%JMAX-Mesh%JMIN+1, 1 /)
       start(:)  = (/ Mesh%IMIN, Mesh%JMIN, 1 /)
       this%error = nf90_put_var(this%ncid,posid,&
            Mesh%bcenter(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,1), &
            start=start,count=num)
       start(:)  = (/ Mesh%IMIN, Mesh%JMIN, 2 /)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_var(this%ncid,posid,&
            Mesh%bcenter(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,2), &
            start=start,count=num)

    END IF
    IF (this%error.NE.NF90_NOERR) CALL Error(this,"WritePositions_netcdf",&
         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE WritePositions_netcdf

  SUBROUTINE WriteCPositions_netcdf(this,Mesh,cposid)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    TYPE(Mesh_TYP)   :: Mesh
    INTEGER          :: cposid, k
    !------------------------------------------------------------------------!
    INTEGER, DIMENSION(4) :: start, num
    !------------------------------------------------------------------------!
    INTENT(IN)       :: Mesh,cposid
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    ! define array shape and slices
    num(:)    = (/ Mesh%IMAX-Mesh%IMIN+1, Mesh%JMAX-Mesh%JMIN+1, 4, 1 /)
    start(:)  = (/ Mesh%IMIN, Mesh%JMIN, 1, 1 /)

    ! write corner positions to file
    ! x-coordinates
    this%error = nf90_put_var(this%ncid,cposid,&
         Mesh%ccart(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,:,1), &
         start=start,count=num)
    ! y-coordinates
    start(:)  = (/ Mesh%IMIN, Mesh%JMIN, 1, 2 /)
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_put_var(this%ncid,cposid,&
              Mesh%ccart(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,:,2), &
              start=start,count=num)

    IF (this%error.NE.NF90_NOERR) CALL Error(this,"WriteCPositions_netcdf",&
         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE WriteCPositions_netcdf

  !> \public Writes timestamp to file
  !!
  SUBROUTINE WriteTimestamp_netcdf(this,time)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this  !< \param [in,out] this fileio type
    REAL             :: time  !< \param [in] time timestamp
    !------------------------------------------------------------------------!
    INTEGER          :: varid
    INTEGER          :: start(1), outnum(1)
    REAL             :: out_time(1)
    !------------------------------------------------------------------------!
    INTENT(IN)       :: time
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    ! get the id of the time stamp variable
    this%error = nf90_inq_varid(this%ncid,TIME_NAME,varid)
#ifdef PARALLEL
    ! change the access mode for the time stamp variable
    IF (this%error.NE.NF90_NOERR) &
         this%error = nf90_var_par_access(this%ncid,varid,NF90_INDEPENDENT)
#endif
    ! only the rank 0 process writes the time stamp
    IF (GetRank(this).EQ.0) THEN
       IF (this%error.EQ.NF90_NOERR) THEN
          IF (this%cycles.EQ.0) THEN
             start(1) = this%step + 1
             outnum(1) = 1
             out_time(1) = time
             this%error = nf90_put_var(this%ncid,varid,out_time,start=start,count=outnum)
          ELSE
             this%error = nf90_put_var(this%ncid,varid,time)
          END IF
       END IF
    END IF
    IF (this%error.NE.NF90_NOERR) CALL Error(this,"WriteTimestamp_netcdf",&
         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE WriteTimestamp_netcdf

  !> \public Reads timestamp to file
  !!
  SUBROUTINE ReadTimestamp_netcdf(this,time)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this  !< \param [in,out] this fileio type
    REAL             :: time  !< \param [out] time timestamp
    !------------------------------------------------------------------------!
    INTEGER          :: varid,ndims,len
    INTEGER, DIMENSION(1) :: dimids,start,num
    REAL, DIMENSION(1)    :: max_time
    !------------------------------------------------------------------------!
    INTENT(OUT)      :: time
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    ! get the id of the time stamp variable
    this%error = nf90_inq_varid(this%ncid,TIME_NAME,varid)
    ! check the dimension (should be 0 or 1)
    IF (this%error.EQ.NF90_NOERR) &
         this%error = nf90_inquire_variable(this%ncid,varid,ndims=ndims)
    IF (this%error.EQ.NF90_NOERR) THEN
       IF (ndims.EQ.0) THEN
          ! read one time stamp
          this%error = nf90_get_var(this%ncid,varid,time)
       ELSE IF (ndims.EQ.1) THEN
          ! several time stamps -> vector, get the associated dimension ID
          this%error = nf90_inquire_variable(this%ncid,varid,dimids=dimids)
          ! number of time stamps
          IF (this%error.EQ.NF90_NOERR) &
               this%error = nf90_inquire_dimension(this%ncid,dimids(1),len=len)
          ! get the last time stamp
          start(1) = len
          num(1) = 1
          IF (this%error.EQ.NF90_NOERR) &
               this%error = nf90_get_var(this%ncid,varid,max_time,start=start,count=num)          
          time = max_time(1)
       END IF
    END IF
    ! return a negative value if reading fails
    IF (this%error.NE.NF90_NOERR) &
         time=-1.0
  END SUBROUTINE ReadTimestamp_netcdf

  !> \public Writes all primitive data arrays to a file 
  !!
  SUBROUTINE WriteDataset_netcdf(this,Mesh,Physics,Timedisc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this      !< \param [in,out] this fileio type
    TYPE(Mesh_TYP)    :: Mesh      !< \param [in] mesh mesh type
    TYPE(Physics_TYP) :: Physics   !< \param [in] physics physics type
    TYPE(Timedisc_TYP):: Timedisc  !< \param [in] timedisc timedisc type
    !------------------------------------------------------------------------!
    INTEGER           :: k
    INTEGER           :: varid
    INTEGER, DIMENSION(this%rank+1) :: start, num
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics,Timedisc
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!
!#ifdef HAVE_HDF5
!    DO k=1, Physics%VNUM
!        CALL SetAttr(this%config, TRIM("timedisc/"//Physics%pvarname(k)), &
!                     Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,k))
!    END DO
!    IF (this%error.EQ.NF90_NOERR) &
!        this%error = SaveDict(this%config, this%ncid)
!#else
    IF (Mesh%JNUM.EQ.1) THEN
       start(1) = Mesh%IMIN
       num(1)   = Mesh%IMAX-Mesh%IMIN+1
    ELSE IF (Mesh%INUM.EQ.1) THEN
       start(1) = Mesh%JMIN
       num(1)   = Mesh%JMAX-Mesh%JMIN+1
    ELSE
       num(1)   = Mesh%IMAX-Mesh%IMIN+1
       num(2)   = Mesh%JMAX-Mesh%JMIN+1
       start(1) = Mesh%IMIN
       start(2) = Mesh%JMIN
    END IF
    ! time step to write
    IF (this%cycles.GT.0) THEN
       start(this%rank+1) = 1
    ELSE
       start(this%rank+1) = this%step + 1
    END IF
    num(this%rank+1) = 1   ! one time step
    ! write the data
    DO k=1,Physics%VNUM
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_inq_varid(this%ncid,TRIM(Physics%pvarname(k)),varid)
       IF (this%error.EQ.NF90_NOERR) &
            this%error = nf90_put_var(this%ncid,varid,&
                         Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,k), &
                         start=start,count=num)
    END DO
!#endif
  END SUBROUTINE WriteDataset_netcdf

  !> \public Reads the data arrays from file (not yet implemented)
  !!
  SUBROUTINE ReadDataset_netcdf(this,Mesh,Physics,Timedisc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this      !< \param [in,out] this fileio type
    TYPE(Mesh_TYP)    :: Mesh      !< \param [in] mesh mesh type
    TYPE(Physics_TYP) :: Physics   !< \param [in] physics physics type
    TYPE(Timedisc_TYP):: Timedisc  !< \param [in,out] timedisc timedisc type
    !------------------------------------------------------------------------!
    INTEGER           :: k
    INTEGER           :: varid,ndims,len
    INTEGER, DIMENSION(this%rank+1)   :: dimids,start,num,map
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics
    INTENT(INOUT)     :: this,Timedisc
    !------------------------------------------------------------------------!
    ! IMPORTANT: check header before reading the data to be sure that
    !            the dimensions are correct
    ! set the extent of the data fields
    
    !Exactly the same as WriteDataset, but nf90_get_var. Not honoring time
    !series yet.
    IF (Mesh%JNUM.EQ.1) THEN
       start(1) = Mesh%IMIN
       num(1)   = Mesh%IMAX-Mesh%IMIN+1
       map(1)   = 1
    ELSE IF (Mesh%INUM.EQ.1) THEN
       start(1) = Mesh%JMIN
       num(1)   = Mesh%JMAX-Mesh%JMIN+1
       map(1)   = 1
    ELSE
       num(1)   = Mesh%JMAX-Mesh%JMIN+1
       num(2)   = Mesh%IMAX-Mesh%IMIN+1
       start(2) = Mesh%JMIN
       start(1) = Mesh%IMIN
       map(1)   = Mesh%INUM
       map(2)   = 1
    END IF
    ! time step to write
    IF (this%cycles.GT.0) THEN
       start(this%rank+1) = 1
    ELSE
       start(this%rank+1) = this%step + 1
    END IF
    num(this%rank+1) = 1   ! one time step
    map(3) = 1
    map(2) = map(2) * map(3)
    map(1) = map(1) * map(3)
    ! write the data
!    DO k=1,Physics%VNUM
!       IF (this%error.EQ.NF90_NOERR) &
!            this%error = nf90_inq_varid(this%ncid,TRIM(Physics%pvarname(k)),varid)
!       IF (this%error.EQ.NF90_NOERR) &
!            this%error = nf90_get_var(this%ncid,varid,&
!                         Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,k), &
!                         start=start,count=num,map=map)
!    END DO
!    IF (this%error.NE.NF90_NOERR) CALL Error(this,"ReadDataset_netcdf",&
!         TRIM(nf90_strerror(this%error)))

!    IF (Mesh%JNUM.EQ.1) THEN
!       start(1) = Mesh%IMIN
!       num(1) = Mesh%IMAX-Mesh%IMIN+1
!    ELSE IF (Mesh%INUM.EQ.1) THEN
!       start(1) = Mesh%JMIN
!       num(1) = Mesh%JMAX-Mesh%JMIN+1
!    ELSE
!       num(:)    = (/ Physics%VNUM, Mesh%JNUM, Mesh%INUM /)
!       start(:)  = (/ 1, Mesh%JMIN, Mesh%IMIN /)
!       map(:)   = (/ Mesh%JNUM*Mesh%INUM, Mesh%INUM, 1/)
!    END IF
!    num(this%rank+1) = 1   ! read one time step
!    ! loop over all primitive variables
!    DO k=1,Physics%VNUM
!       ! get the id
!       this%error = nf90_inq_varid(this%ncid,TRIM(Physics%pvarname(k)),varid)
!       ! check for time series
!       IF (this%error.EQ.NF90_NOERR) &
!            this%error = nf90_inquire_variable(this%ncid,varid,ndims=ndims)
!       IF (ndims.EQ.this%rank+1) THEN
!          ! yes we have a time series
!          IF (this%error.EQ.NF90_NOERR) &
!               this%error = nf90_inquire_variable(this%ncid,varid,dimids=dimids)
!          ! get the length of the time series
!          IF (this%error.EQ.NF90_NOERR) &
!               this%error = nf90_inquire_dimension(this%ncid,dimids(this%rank+1),len=len)
!       ELSE
!          len = 1
!       END IF
!       ! read the data of the (last) time step
!       ! set the time step we want to read (last, i.e. most recent)
!       start(this%rank+1) = len-1
!       ! read the data
!       IF (this%error.EQ.NF90_NOERR) &
!            this%error = nf90_get_var(this%ncid,varid,&
!                         Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JMIN:Mesh%JMAX,k), &
!                         start=start,count=num,map=map)
!       print *,"this error(noerr:",NF90_NOERR,"): ",this%error
!    END DO
!    IF (this%error.NE.NF90_NOERR) CALL Error(this,"ReadDataset_netcdf",&
!         TRIM(nf90_strerror(this%error)))
  END SUBROUTINE ReadDataset_netcdf
#endif

  !> \public Closes the file I/O
  !!
  SUBROUTINE CloseFileIO_netcdf(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this   !< \param [in,out] this fileio type
    !------------------------------------------------------------------------!
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
  END SUBROUTINE CloseFileIO_netcdf


END MODULE fileio_netcdf
