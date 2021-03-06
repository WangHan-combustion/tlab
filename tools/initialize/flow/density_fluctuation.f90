#include "types.h"
#include "dns_const.h"

!########################################################################
!# DESCRIPTION
!#
!# Setting up a perturbation of the thermodynamic fields by a 
!# displacement of the reference center plane.
!#
!# Array s enters with the scalar total field, including fluctuations.
!#
!########################################################################
SUBROUTINE DENSITY_FLUCTUATION(code, s, p, rho, T, h, disp, wrk3d)

  USE DNS_GLOBAL,    ONLY : g
  USE DNS_GLOBAL,    ONLY : imax,jmax,kmax, isize_field, area
  USE DNS_GLOBAL,    ONLY : imode_flow
  USE DNS_GLOBAL,    ONLY : rbg, tbg
  USE THERMO_GLOBAL, ONLY : imixture
  USE FLOW_LOCAL
#ifdef USE_MPI
  USE DNS_MPI, ONLY :  ims_offset_k
#endif

  IMPLICIT NONE

#include "integers.h"

  TINTEGER code

  TREAL, DIMENSION(imax,jmax,kmax)   :: T, h, rho, p, wrk3d
  TREAL, DIMENSION(imax,jmax,kmax,*) :: s
  TREAL, DIMENSION(imax,kmax)        :: disp

! -------------------------------------------------------------------
  TINTEGER i, j, k, inx2d, inx3d, inz3d
  TINTEGER idummy, idsp, iprof_loc
  TREAL wx, wz, wxloc, wzloc, dummy, ycenter, mean_loc, delta_loc
  TREAL AVG_IK, FLOW_SHEAR_TEMPORAL
  TREAL xcenter, amplify

  TREAL, DIMENSION(:), POINTER :: x,y,z, dx,dz
  
! ###################################################################
! Define pointers
  x => g(1)%nodes; dx => g(1)%jac(:,1)
  y => g(2)%nodes
  z => g(3)%nodes; dz => g(3)%jac(:,1)

  disp = C_0_R

! ###################################################################
! Center plane displacement
! ###################################################################
! -------------------------------------------------------------------
! Broadband case
! -------------------------------------------------------------------
  IF ( code .EQ. 4 ) THEN
     idummy = g(2)%size; g(2)%size = 1
     CALL DNS_READ_FIELDS('scal.rand', i1, imax,i1,kmax, i1,i0, isize_field, disp, wrk3d)
     g(2)%size = idummy
! remove mean
     dummy = AVG_IK(imax, i1, kmax, i1, disp, dx, dz, area)
     disp = disp -dummy

  ENDIF

! -------------------------------------------------------------------
! Discrete case
! -------------------------------------------------------------------
  IF ( code .EQ. 5 ) THEN
     wx = C_2_R*C_PI_R /g(1)%scale
     wz = C_2_R*C_PI_R /g(3)%scale

! 1D perturbation along X
     DO inx2d = 1,nx2d
        wxloc = M_REAL(inx2d)*wx
        DO k = 1,kmax
           DO i = 1,imax
              disp(i,k) = disp(i,k) + &
                   A2d(inx2d)*COS(wxloc*x(i)+Phix2d(inx2d))
           ENDDO
        ENDDO
     ENDDO

! 2D perturbation along X and Z
     IF ( g(3)%size .GT. 1 ) THEN
#ifdef USE_MPI
        idsp = ims_offset_k 
#else
        idsp = 0
#endif
        DO inx3d = 1,nx3d
           DO inz3d = 1,nz3d
              wxloc = M_REAL(inx3d)*wx
              wzloc = M_REAL(inz3d)*wz
              DO k = 1,kmax
                 DO i = 1,imax
                    disp(i,k) = disp(i,k) + &
                         A3d(inx3d)*COS(wxloc*x(i)+Phix3d(inx3d))* &
                         COS(wzloc*z(idsp+k)+Phiz3d(inz3d))
                 ENDDO
              ENDDO
           ENDDO
        ENDDO
     ENDIF

  ENDIF

! -------------------------------------------------------------------
! Modulation
! -------------------------------------------------------------------
  IF ( frc_delta .GT. C_0_R ) THEN
     DO k = 1,kmax
        DO i = 1,imax
           xcenter   = x(i) - g(1)%scale *C_05_R - x(1)
           amplify   = EXP(-(C_05_R*xcenter/frc_delta)**2)
           disp(i,k) = disp(i,k)*amplify
        ENDDO
     ENDDO
  ENDIF

! ###################################################################
! Perturbation in the thermodynamic fields
! ###################################################################
  IF ( imode_flow .EQ. DNS_FLOW_SHEAR ) THEN
! -------------------------------------------------------------------
! temperature
! -------------------------------------------------------------------
     IF ( rbg%type .EQ. PROFILE_NONE ) THEN

! temperature/mixture profile is given
        IF ( tbg%type .GT. 0 ) THEN
           DO k = 1,kmax
              DO i = 1,imax
                 delta_loc = tbg%delta + (tbg%parameters(2)-tbg%parameters(1))*disp(i,k) *g(2)%scale
                 mean_loc  = tbg%mean  + C_05_R*(tbg%parameters(2)+tbg%parameters(1))*disp(i,k) *g(2)%scale
                 ycenter   = y(1) + g(2)%scale *tbg%ymean + disp(i,k)
                 DO j = 1,jmax
                    T(i,j,k) =  FLOW_SHEAR_TEMPORAL&
                         (tbg%type, tbg%thick, delta_loc, mean_loc, ycenter, tbg%parameters, y(j))
                 ENDDO
              ENDDO
           ENDDO

           IF ( imixture .EQ. MIXT_TYPE_AIRWATER ) THEN
              CALL THERMO_AIRWATER_PT(imax, jmax, kmax, s, p, T)
           ENDIF

! enthalpy/mixture profile is given
        ELSE IF ( tbg%type .LT. 0 ) THEN
           DO k = 1,kmax
              DO i = 1,imax
                 delta_loc = tbg%delta + (tbg%parameters(2)-tbg%parameters(1))*disp(i,k) *g(2)%scale
                 mean_loc  = tbg%mean  + C_05_R*(tbg%parameters(2)+tbg%parameters(1))*disp(i,k) *g(2)%scale
                 ycenter   = y(1) + g(2)%scale *tbg%ymean + disp(i,k)
                 iprof_loc =-tbg%type
                 DO j = 1,jmax
                    h(i,j,k) =  FLOW_SHEAR_TEMPORAL&
                         (iprof_loc, tbg%thick, delta_loc, mean_loc, ycenter, tbg%parameters, y(j))
                 ENDDO
              ENDDO
           ENDDO

           IF ( imixture .EQ. MIXT_TYPE_AIRWATER ) THEN
              CALL THERMO_AIRWATER_PH_RE(imax,jmax,kmax, s, p, h, T)
           ENDIF

        ENDIF

! compute perturbation in density
        CALL THERMO_THERMAL_DENSITY(imax,jmax,kmax, s, p, T, rho)

     ELSE

! -------------------------------------------------------------------
! density
! -------------------------------------------------------------------
! to be developed
     ENDIF

  ENDIF

  RETURN
END SUBROUTINE DENSITY_FLUCTUATION
