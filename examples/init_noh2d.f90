!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: init_noh2d.f90                                                    #
!#                                                                           #
!# Copyright (C) 2008-2010                                                   #
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
! Program and data initialization for 2D Noh problem
! References:
! [1] Noh, W. F.: Errors for calculations of strong shocks using an artificial
!     viscosity and an artificial heat-flux, J. Comput. Phys. 72 (1987), 78-120
!     DOI: 10.1016/0021-9991(87)90074-X
! [2] Rider, W. J.: Revisiting wall heating, J. Comput. Phys. 162 (2000), 395-410
!     DOI: 10.1006/jcph.2000.6544
! [3] Liska, R and Wendroff, B: Comparison of several difference schemes on
!     1D and 2D test problems for the Euler equations, SIAM J. Sci. Comput.
!     25(3) (2003), 995-1017
!     preprint: http://www.math.unm.edu/~bbw/sisc.pdf
!     DOI: 10.1137/S1064827502402120 
!----------------------------------------------------------------------------!
MODULE Init
  USE physics_generic
  USE fluxes_generic
  USE mesh_generic
  USE reconstruction_generic
  USE boundary_generic
  USE fileio_generic
  USE timedisc_generic
  IMPLICIT NONE
  !--------------------------------------------------------------------------!
  PRIVATE
  ! simulation parameters
  REAL, PARAMETER    :: TSIM    = 2.0      ! simulation stop time
  REAL, PARAMETER    :: GAMMA   = 5./3.    ! ratio of specific heats
  ! initial condition (dimensionless units)
  REAL, PARAMETER    :: RHO0    = 1.0      ! density
  REAL, PARAMETER    :: P0      = 1.0E-6   ! pressure
  REAL, PARAMETER    :: VR0     = -1.0     ! radial velocity
  ! mesh settings
  INTEGER, PARAMETER :: MGEO = CARTESIAN   ! geometry
!!$  INTEGER, PARAMETER :: MGEO = POLAR
!!$  INTEGER, PARAMETER :: MGEO = LOGPOLAR
!!$  INTEGER, PARAMETER :: MGEO = TANPOLAR
!!$  INTEGER, PARAMETER :: MGEO = SINHPOLAR
  INTEGER, PARAMETER :: XRES = 100         ! x-resolution
  INTEGER, PARAMETER :: YRES = 100         ! y-resolution
  REAL, PARAMETER    :: RMIN = 1.0E-3      ! inner radius for polar grids
  REAL, PARAMETER    :: RMAX = 1.0         ! outer radius
  REAL, PARAMETER    :: GPAR = 0.5         ! geometry scaling parameter
  ! output parameters
  INTEGER, PARAMETER :: ONUM = 10          ! number of output data sets
  CHARACTER(LEN=256), PARAMETER &          ! output data dir
                     :: ODIR = './'
  CHARACTER(LEN=256), PARAMETER &          ! output data file name
                     :: OFNAME = 'noh2d' 
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       ! methods
       InitProgram
  !--------------------------------------------------------------------------!


CONTAINS

  SUBROUTINE InitProgram(Mesh,Physics,Fluxes,Timedisc,Datafile,Logfile)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Mesh_TYP)    :: Mesh
    TYPE(Physics_TYP) :: Physics
    TYPE(Fluxes_TYP)  :: Fluxes
    TYPE(Timedisc_TYP):: Timedisc
    TYPE(FILEIO_TYP)  :: Datafile
    TYPE(FILEIO_TYP)  :: Logfile
    !------------------------------------------------------------------------!
    ! Local variable declaration
    INTEGER           :: bc(4)
    REAL              :: x1,x2,y1,y2
    !------------------------------------------------------------------------!
    INTENT(OUT)       :: Mesh,Physics,Fluxes,Timedisc,Datafile,Logfile
    !------------------------------------------------------------------------!
    ! physics settings
    CALL InitPhysics(Physics, &
         problem = EULER2D, &
         gamma   = GAMMA, &         ! ratio of specific heats        !
         dpmax   = 1.0E+10)         ! for advanced time step control !

    ! numerical scheme for flux calculation
    CALL InitFluxes(Fluxes, &
         scheme = MIDPOINT)         ! quadrature rule                !

    ! reconstruction method
    CALL InitReconstruction(Fluxes%reconstruction, &
         order     = LINEAR, &
         ! IMPORTANT: always use primitive reconstruction for NOH problem
         variables = PRIMITIVE, &   ! vars. to use for reconstruction!
         limiter   = MONOCENT, &
         theta     = 1.2)           ! optional parameter for limiter !

    ! mesh settings and boundary conditions
    SELECT CASE(MGEO)
    CASE(CARTESIAN)
       x1 =-RMAX
       x2 = RMAX
       y1 =-RMAX 
       y2 = RMAX
       bc(WEST)  = NOH2D
       bc(EAST)  = NOH2D
       bc(SOUTH) = NOH2D
       bc(NORTH) = NOH2D
    CASE(POLAR)
       x1 = RMIN
       x2 = RMAX
       y1 = 0.0 
       y2 = 2*PI       
       bc(WEST)  = AXIS
       bc(EAST)  = NOH2D
       bc(SOUTH) = PERIODIC
       bc(NORTH) = PERIODIC
    CASE(LOGPOLAR)
       x1 = LOG(RMIN/GPAR)
       x2 = LOG(RMAX/GPAR)
       y1 = 0.0 
       y2 = 2*PI       
       bc(WEST)  = AXIS
       bc(EAST)  = NOH2D
       bc(SOUTH) = PERIODIC
       bc(NORTH) = PERIODIC
    CASE(TANPOLAR)
       x1 = ATAN(RMIN/GPAR)
       x2 = ATAN(RMAX/GPAR)
       y1 = 0.0 
       y2 = 2*PI       
       bc(WEST)  = AXIS
       bc(EAST)  = NOH2D
       bc(SOUTH) = PERIODIC
       bc(NORTH) = PERIODIC
    CASE(SINHPOLAR)
       x1 = RMIN/GPAR
       x1 = LOG(x1+SQRT(1.0+x1*x1))  ! = ASINH(RMIN/GPAR))
       x2 = RMAX/GPAR
       x2 = LOG(x2+SQRT(1.0+x2*x2))  ! = ASINH(RMAX/GPAR))
       y1 = 0.0 
       y2 = 2*PI       
       bc(WEST)  = AXIS
       bc(EAST)  = NOH2D
       bc(SOUTH) = PERIODIC
       bc(NORTH) = PERIODIC
    CASE DEFAULT
       CALL Error(Physics,"InitProgram","mesh geometry not supported for 2D Noh problem")
    END SELECT

    ! mesh setttings
    CALL InitMesh(Mesh,Fluxes, &
         geometry = MGEO, &
             inum = XRES, &
             jnum = YRES, &
             xmin = x1, &
             xmax = x2, &
             ymin = y1, &
             ymax = y2, &
           gparam = GPAR)

    ! boundary conditions
    CALL InitBoundary(Timedisc%boundary,Mesh,Physics, &
         western  = bc(WEST), &
         eastern  = bc(EAST), &
         southern = bc(SOUTH), &
         northern = bc(NORTH))
 
   ! time discretization settings
    CALL InitTimedisc(Timedisc,Mesh,Physics,&
         method   = MODIFIED_EULER, &
         order    = 3, &
         cfl      = 0.4, &
         stoptime = TSIM, &
         dtlimit  = 1.0E-6, &
         maxiter  = 100000)

    ! set initial condition
    CALL InitData(Mesh,Physics,Timedisc)

    ! initialize log input/output
!!$    CALL InitFileIO(Logfile,Mesh,Physics,Timedisc,&
!!$         fileformat = BINARY, &
!!$         filename   = TRIM(ODIR) // TRIM(OFNAME) // 'log', &
!!$         filecycles = 1)

    ! initialize data input/output
    CALL InitFileIO(Datafile,Mesh,Physics,Timedisc, &
!!$         fileformat = VTK, &
         fileformat = GNUPLOT, filecycles = 0, &
         filename   = TRIM(ODIR) // TRIM(OFNAME), &
         count      = ONUM)
  END SUBROUTINE InitProgram


  SUBROUTINE InitData(Mesh,Physics,Timedisc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Physics_TYP)  :: Physics
    TYPE(Mesh_TYP)     :: Mesh
    TYPE(Timedisc_TYP) :: Timedisc
    !------------------------------------------------------------------------!
    ! Local variable declaration
    REAL, DIMENSION(Mesh%IGMIN:Mesh%IGMAX,Mesh%JGMIN:Mesh%JGMAX,2) :: vcart
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics
    INTENT(INOUT)     :: Timedisc
    !------------------------------------------------------------------------!
    ! initial condition
    Timedisc%pvar(:,:,Physics%DENSITY)   = RHO0
    Timedisc%pvar(:,:,Physics%PRESSURE)  = P0
    ! cartesian components of the velocity
    vcart(:,:,1) = VR0 * Mesh%bccart(:,:,1) / &
         SQRT(Mesh%bccart(:,:,1)**2 + Mesh%bccart(:,:,2)**2)
    vcart(:,:,2) = vcart(:,:,1) * Mesh%bccart(:,:,2) / Mesh%bccart(:,:,1)
    CALL Convert2Curvilinear(Mesh%geometry,Mesh%bcenter,vcart,&
         Timedisc%pvar(:,:,Physics%XVELOCITY:Physics%YVELOCITY))

    ! supersonic inflow boundary conditions at outer boundaries;
    ! set boundary data equal to initial values in ghost cells
    IF (GetType(Timedisc%boundary(WEST)).EQ.NOH2D) &
       Timedisc%boundary(WEST)%data(:,:,:) = &
       Timedisc%pvar(Mesh%IGMIN:Mesh%IMIN-1,Mesh%JMIN:Mesh%JMAX,:)
    IF (GetType(Timedisc%boundary(EAST)).EQ.NOH2D) &
       Timedisc%boundary(EAST)%data(:,:,:) = &
       Timedisc%pvar(Mesh%IMAX+1:Mesh%IGMAX,Mesh%JMIN:Mesh%JMAX,:)
    IF (GetType(Timedisc%boundary(SOUTH)).EQ.NOH2D) &
       Timedisc%boundary(SOUTH)%data(:,:,:) = &
       Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JGMIN:Mesh%JMIN-1,:)
    IF (GetType(Timedisc%boundary(NORTH)).EQ.NOH2D) &
       Timedisc%boundary(NORTH)%data(:,:,:) = &
       Timedisc%pvar(Mesh%IMIN:Mesh%IMAX,Mesh%JMAX+1:Mesh%JGMAX,:)

    CALL Convert2Conservative(Physics,Mesh,Timedisc%pvar,Timedisc%cvar)
    CALL Info(Mesh, " DATA-----> initial condition: 2D Noh problem")
  END SUBROUTINE InitData

END MODULE Init
