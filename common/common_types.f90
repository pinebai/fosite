!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: common_types.f90                                                  #
!#                                                                           #
!# Copyright (C) 2006-2008                                                   #
!# Tobias Illenseer <tillense@astrophysik.uni-kiel.de>                       #
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
! basic data and methods common to all objects
!----------------------------------------------------------------------------!
MODULE common_types
#ifdef PARALLEL
#ifdef HAVE_MPI_MOD
  USE mpi
#endif
#endif
  IMPLICIT NONE
#ifdef PARALLEL
#ifdef HAVE_MPIF_H
  include 'mpif.h'
#endif
#endif
  !--------------------------------------------------------------------------!
  PRIVATE
  ! common data structure
  TYPE Common_TYP
     PRIVATE
     INTEGER           :: type
     CHARACTER(LEN=32) :: name
     INTEGER           :: error               ! error code                   !
     LOGICAL           :: init = .FALSE.      ! init status                  !
     INTEGER, POINTER  :: myrank              ! rank of parallel process     !
     INTEGER, POINTER  :: ppnum               ! number of parallel processes !
     LOGICAL, POINTER  :: parinit             ! init status of par. process  !
  END TYPE Common_TYP
  ! these variables should be the same for all objects
  ! of the current process
#ifdef PARALLEL
  INTEGER, SAVE :: DEFAULT_MPI_REAL = MPI_REAL   ! default real type for MPI !
  REAL, PARAMETER :: dummy=1.0                   ! check default real type   !
#endif
  INTEGER, SAVE, TARGET :: myrank = 0, ppnum = 1
  LOGICAL, SAVE, TARGET :: parinit = .FALSE. 
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       ! types
       Common_TYP, &
#ifdef PARALLEL
       DEFAULT_MPI_REAL, &
#endif
       ! methods
       InitCommon, &
       CloseCommon, &
       GetType, &
       GetName, &
       GetRank, &
       GetNumProcs, &
       Initialized, &
       Info, &
       Warning, &
       Error
  !--------------------------------------------------------------------------!

CONTAINS

  SUBROUTINE InitCommon(this,t,n)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP)  :: this
    INTEGER           :: t
    CHARACTER(LEN=*)  :: n
    !------------------------------------------------------------------------!
    INTENT(IN)        :: t,n
    INTENT(OUT)       :: this
    !------------------------------------------------------------------------!
    this%type = t
    this%name = n
    this%myrank => myrank
    this%ppnum => ppnum
    this%parinit => parinit
#ifdef PARALLEL
    IF (.NOT.parinit) THEN
       CALL MPI_Comm_rank(mpi_comm_world,this%myrank,this%error)
       CALL MPI_Comm_size(mpi_comm_world,this%ppnum,this%error)
       this%parinit = .TRUE.
       ! determine the default MPI data type for real numbers
       SELECT CASE (SELECTED_REAL_KIND(PRECISION(dummy)))
       CASE(4)
          DEFAULT_MPI_REAL = MPI_REAL4
       CASE(8)
          DEFAULT_MPI_REAL = MPI_REAL8
       CASE DEFAULT
          CALL Warning(this,"InitCommon","Cannot determine default MPI real types.")
       END SELECT
    END IF
#endif
    this%error = 0
    this%init  = .TRUE.
  END SUBROUTINE InitCommon


  SUBROUTINE CloseCommon(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP) :: this
    !------------------------------------------------------------------------!
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    this%init = .FALSE.
  END SUBROUTINE CloseCommon


  PURE FUNCTION GetType(this) RESULT(t)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    INTEGER :: t
    !------------------------------------------------------------------------!
    t = this%type
  END FUNCTION GetType


  PURE FUNCTION GetName(this) RESULT(n)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    CHARACTER(LEN=32) :: n
    !------------------------------------------------------------------------!
    n = this%name
  END FUNCTION GetName


  PURE FUNCTION GetRank(this) RESULT(r)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    INTEGER :: r
    !------------------------------------------------------------------------!
    r = this%myrank
  END FUNCTION GetRank


  PURE FUNCTION GetNumProcs(this) RESULT(p)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    INTEGER :: p
    !------------------------------------------------------------------------!
    p = this%ppnum
  END FUNCTION GetNumProcs


  PURE FUNCTION Initialized(this) RESULT(i)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    LOGICAL :: i
    !------------------------------------------------------------------------!
    i = this%init
  END FUNCTION Initialized


  SUBROUTINE Info(this,msg,rank,node_info)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN)  :: this
    CHARACTER(LEN=*),  INTENT(IN) :: msg
    INTEGER, OPTIONAL, INTENT(IN) :: rank
    LOGICAL, OPTIONAL, INTENT(IN) :: node_info
    !------------------------------------------------------------------------!
#ifdef PARALLEL
    INTEGER :: ierr
#endif
    INTEGER :: print_rank
    LOGICAL :: print_node_info
    !------------------------------------------------------------------------!
    IF (PRESENT(rank)) THEN
       print_rank = rank
    ELSE
       print_rank = 0
    END IF
    IF (PRESENT(node_info)) THEN
       print_node_info = node_info
    ELSE
       print_node_info = .FALSE.
    END IF
#ifdef PARALLEL 
    IF (.NOT.parinit) CALL MPI_Comm_rank(mpi_comm_world,myrank,ierr)
#endif
    ! use "myrank" here instead of "this%myrank" 
    ! because "this" might be uninitialized
    IF (myrank.EQ.print_rank) THEN
#ifdef PARALLEL
       IF (print_node_info) &
            WRITE (0,'(A,I4.4,A)',ADVANCE='NO') "NODE [", myrank, "] "
#endif
       WRITE (*,'(A)') TRIM(msg)
    END IF
  END SUBROUTINE Info


  SUBROUTINE Warning(this,modproc,msg)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN) :: this
    CHARACTER(LEN=*),  INTENT(IN) :: modproc,msg
    !------------------------------------------------------------------------!
    CALL Info(this,"WARNING in " // TRIM(modproc) // ": " // TRIM(msg),&
         myrank,.TRUE.)
  END SUBROUTINE Warning


  SUBROUTINE Error(this,modproc,msg,rank)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Common_TYP), INTENT(IN)  :: this
    CHARACTER(LEN=*),  INTENT(IN) :: modproc,msg
    INTEGER, OPTIONAL, INTENT(IN) :: rank
    !------------------------------------------------------------------------!
#ifdef PARALLEL
    INTEGER :: ierr
#endif
    !------------------------------------------------------------------------!
    CALL Info(this,"ERROR in " // TRIM(modproc) // ": " // TRIM(msg),&
         rank,.TRUE.)
    ! abort execution
#ifdef PARALLEL
    CALL MPI_Abort(MPI_COMM_WORLD,1,ierr)
#else
    STOP
#endif
  END SUBROUTINE Error

END MODULE common_types
