#!/usr/bin/env python
"""
Created on Sun Feb 24 2020
@author: Zhifeng Hu <zhh076@ucsd.edu>
    Input:
        *.srf (string): srf source file from CyberShake
        mesh (string): mesh file (la_habra_small_cvmsi_8m_3456.media), including vp, vs, rho

    Output: subfaults.idx, fault information
        sliprate.bin, sliprate time history on each subfault
"""

import numpy as np
from numpy import sin, cos, pi, sqrt
from scipy.signal import resample
from scipy import spatial
import sys
import glob
import collections
import pickle
from pathlib import Path
from filter_BU import filt_B

def upsample(s1, dt1, dt2, nt2):
    '''
    For upsample only, since no anti-aliasing is implemented.
    '''
    s2 = np.zeros((nt2,))
    for n in range(nt2):
        t_n = dt2 * n
        n_l = np.floor(t_n / dt1)
        n_r = np.ceil(t_n / dt1)
        if n_l==n_r:
            s2[n] = s1[n_l] 
        elif n_r > len(s1) - 1:
            s2[n] = s1[n_l]
        else:
            t_l = n_l * dt1
            t_r = n_r * dt1
            s2[n] = s1[n_l] + (s1[n_r] - s1[n_l]) * (t_n - t_l) / (t_r - t_l)
    return s2

nt_ref = 5000
dt = 0.001
dz = 0.020
theta_rot = 39.9

mx, my = 9504, 7020
mz = 360  # 250*24 = 6km > (4.5 + 2.5) - 1.216
block_top = 0
xoff_0, xoff_1 = 5400, 6200
yoff_0, yoff_1 = 2600, 3400
kx, ky = xoff_1 - xoff_0, yoff_1 - yoff_0

try:
    kdtree = pickle.loads(Path('kdtree.pickle').read_bytes())
except:
    grids = np.fromfile('surf.grid', dtype='float64').reshape(my, mx, 3)
    grids = np.reshape(grids[yoff_0 : yoff_1, xoff_0 : xoff_1, :2], (-1, 2))
    kdtree = spatial.cKDTree(grids)
    with open('kdtree.pickle', 'wb') as fid:
        pickle.dump(kdtree, fid, protocol=pickle.HIGHEST_PROTOCOL)
    del grids

mu = np.zeros((mz, ky, kx), dtype='float64')
with open('../cvm/la_habra_ext_large_cvmsi_20m_p0.media', 'rb') as f_media:
    for i in range(mz):
        try:
            data = np.fromfile(f_media, dtype='float32',
                    count=my*mx*3).reshape(my, mx, 3)
        except:
            print(int(dtop // dz) + i)
        mu[i, :, :] = data[yoff_0 : yoff_1, xoff_0 : xoff_1, 2] \
                      * data[yoff_0 : yoff_1, xoff_0 : xoff_1, 1] ** 2
print(mu.shape)

flist = glob.glob('*20m.srf')
for fname in flist:
    #f = open(glob.glob('./*.srf')[0],'r')
    f = open(fname, 'r')
    print(f'\n computing srf {fname}. \n')
    f.readline()
    f.readline()
    token = f.readline()
    nx = int(token.split()[2])
    nz = int(token.split()[3])
    npt = nx * nz
    final_sr = np.zeros((nx, nz, nt_ref), dtype='float32') # (nx, nz, nt) --> (nt, nz, nx) to save

    dtop = np.floor(float(f.readline().split()[2]) / dz) * dz 
    print(f.readline())

    f_sliprate = open(f"sliprate.bin", 'wb')
    f_fault = open(f"subfaults.idx", 'w')
    
    repeat = collections.defaultdict(list)

    for j in range(nz):
        sys.stdout.write("\rreading subfault %d of %d" % (j+1, nz))
        sys.stdout.flush()
        for i in range(nx):
            sr = np.zeros((nt_ref,))
            nl1 = f.readline().split()
            nl2 = f.readline().split()
            iy, ix = np.unravel_index(kdtree.query([float(nl1[0]), float(nl1[1])])[1], (ky, kx))
            iz = int(round((float(nl1[2]) - block_top) / dz))
            stk = float(nl1[3]) - theta_rot  # Rotate mesh 39.9' clock-wise
            dip = float(nl1[4])
            rake = float(nl2[0])
            area = float(nl1[5]) / 1.e4  # cm^2 --> m^2
            tinit= float(nl1[6])
            dt = float(nl1[7])
            nt1 = int(nl2[2])
            nskip1 = int(np.ceil(nt1 / 6.))
            sliprate1 = np.zeros((nt1), dtype=float)
            p1 = 0
            for l in range(nskip1):
                tmp = f.readline()
                nt = len(tmp.split())
                for n in range(nt):
                    sliprate1[p1] = float(tmp.split()[n]) / 1.e2  # cm/s2 --> m/s2
                    p1 += 1
            t1 = int(np.floor(tinit/dt))
            try:
                sr[t1 : t1+len(sliprate1)] = sliprate1.copy()
            except:
                print(nt1, len(sliprate1), t1)
                print(nl2)
                sys.exit(-1)
            f_fault.write("{0} {1} {2} {3} {4} {5} {6} {7}\n".format(
                        ix + xoff_0 + 1, iy + yoff_0 + 1, iz + 1, area,
                        mu[iz, iy, ix], stk, dip, rake))
            final_sr[i, j, :] += sr
            repeat[(ix, iy, iz)] += (i, j),
            # final_sr[i, j, :] = filt_B(sr, 1/dt, highcut=10, causal=False)
        print(iz)
            
    print(f"Due to downsampling subfualts, there are {len(repeat)} unique subfualt from original {nx * nz}")

#    for k, l in repeat:
#        sr = sum(final_sr[i, j, :] for (i, j) in l)
#        for (i, j) in l:
#            final[i, j, :] = sr

    final_sr = np.float32(final_sr.T)  # (nt, nz, nx)
    final_sr.tofile(f_sliprate)
    f_fault.close()
    f_sliprate.close()

