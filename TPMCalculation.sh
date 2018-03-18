#!/bin/bash

# Calulate the TPM value for each RNA-Seq data
# Run jobs on slurm matchine
# Invoked by:
#
# READPATH=/data/rc003/lu/transcriptome/$i sbatch TPMCalculation.sh
#
# $i=genome (e.g. human)

#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --time=1-00:00
#SBATCH --mem=16GB

# Notification configuration
#SBATCH --mail-type=END                                        
#SBATCH --mail-type=FAIL                                       
#SBATCH --mail-user=lu.zeng@adelaide.edu.au  

# Load Softwares
module load Trim_Galore/0.4.1-foss-2015b
module load RSEM/1.3.0-foss-2015b
module load Bowtie2/2.2.6-foss-2015b 
module load SRA-Toolkit/2.7.0-centos_linux64
module load fastqc/0.11.4  
 
# Extract the uniq names without _1_val_1.fq.gz (for pair-end RNA-Seq data)
FILES=($(ls $READPATH | rev | cut -c 15- | rev | uniq))
# Extract the uniq names without _1_trimmed.fq.gz (for sing-end RNA-Seq data)
FILES=($(ls $READPATH | rev | cut -c 17- | rev | uniq))

# Download RNA-Seq data
wget ftp://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByRun/sra/SRR/SRRxxx/SRRxxxxx/*.sra

# Transfer sra format to fastq format
for i in *.sra
do
fastq-dump.2.7.0 -I --split-files $i
done

# Check the quality of RNA-Seq data
for i in *.fastq
do
    echo $i
    fastqc -o qc/ $i
done

# Adapter trimming the fastq files 
# and then check the RNA-Seq data quality 
trim_galore --stringency 6 -o trim/ --paired -fastqc_args "-t 8" ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_1.fastq.gz ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_2.fastq.gz
# strigency: overlap with adapter sequence required to trim a sequences, default is '1', the lower the number
# the lower strigency

# For single-end RNA-Seq data
trim_galore --clip_R1 5 --three_prime_clip_R1 5 -o trim2/ -fastqc_args "-t 8" ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_1.fastq.gz

# Then prepare rsem reference
~/RSEM-1.3.0/rsem-prepare-reference --gtf $i.gtf --bowtie2 --bowtie2-path /home/lu/bowtie2-2.2.5 ../genomes/$i.fa $i_index/$iGenome

# Then calculate the gene expression (TPM), including pair-end and single-end data
# Pair-end
~/RSEM-1.3.0/rsem-calculate-expression -p 8 --bowtie2 --paired-end ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_1_val_1.fq.gz ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_2_val_2.fq.gz $i_index/$iGenome ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}
# Single-end
~/RSEM-1.3.0/rsem-calculate-expression -p 8 --bowtie2 ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}_1_trimmed.fq.gz $i_index/$iGenome ${READPATH}/${FILES[$SLURM_ARRAY_TASK_ID]}
