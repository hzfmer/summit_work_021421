  -X 64 -Y 64 -Z 400 -x 4 -y 4 -G 1
  --TMAX 150.00   --DH 2.5 --DT 0.0002 
  --ND 20 --ARBC 0.95 --NPC 2
  --NSRC 1 --NST 750000 --READ_STEP 750000
  --IFAULT 6 --INSRC stf_A.txt  
  --INVEL mesh --MEDIASTART 2 
  --IDYNA 0  --NVE 1 --NVAR 5 
  --NBGX 33 --NEDX 33 --NBGY 32 --NEDY 32 
  --NBGZ 1 --NEDZ 41 --NSKPZ 40 --OUT output_sfc 
  --NTISKP 25 --WRITE_STEP 30000
  --FAC 1.0 --Q0 150. --EX 0.2 --FP 1.0