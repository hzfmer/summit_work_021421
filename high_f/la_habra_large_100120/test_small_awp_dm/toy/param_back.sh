  -X 360 -Y 240 -Z 64 -x 3 -y 2 -G 1 
  --TMAX 5.00 --DH 15.0 --DT 0.001 
  --ND 20 --ARBC 0.95 
  --IDYNA 0 --NVE 1 --IFAULT 1 
  --NSRC 0 --MEDIASTART 2
  --INVEL mesh --NVAR 3
  --NTISKP 1 --WRITE_STEP 200 
  --NBGX 1 --NEDX 360 --NBGY 1 --NEDY 240 
  --NBGZ 1 --NEDZ 2
  --OUT output_sfc_new -c output_ckp/ckp
  --SOURCEFILE input/source.txt
  --INTOPO topography.bin
  --FAC 1.0 --Q0 150. --EX 0.0 --FP 1.0