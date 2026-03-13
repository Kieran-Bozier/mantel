To run the tests, use

#Load necessary python libraries
$ conda activate mantel

#Run
$ nohup ./mantel-test.sh &

By default, this script runs on 32 CPU. 
Expected runtime (Intel(R) Xeon(R) Gold 6142 CPU @ 2.60 GHz)

Al
mantel_prep: 170 seconds
mantel_run: 55 seconds

Nb
mantel_prep: 120 seconds
mantel_run: 83 seconds

Ta
mantel_prep: 95 seconds
mantel_run: 80 seconds

H3S
mantel_prep: 134 seconds
mantel_run: 90 seconds

===========================
Total Runtime: ~ 15 minutes
===========================