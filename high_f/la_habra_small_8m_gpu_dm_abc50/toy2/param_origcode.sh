 -X 300 -Y 200 -Z 100 -x 3 -y 2 -G 1
 --TMAX 5.0 --DH 10.0 --DT 0.001 --ND 20 --ARBC 0.95
 --IFAULT 1 --INSRC source
 --IDYNA 0 --NSRC 1 --NST 1000
 --MEDIASTART 2 --NTISKP 10 --WRITE_STEP 500
 --INVEL mesh --NVE 1 --NVAR 3
 -c output_ckp/ckp -o output_sfc
 --FAC 1.0 --Q0 150. --EX 0.0 --FP 1.0