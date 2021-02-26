#!/usr/bin/env nextflow

in_files = params.in_files
out_dir = file(params.out_dir)

Channel.fromFilePairs(in_files)
        { file ->
          b = file.baseName
          m = b =~ /(.*)\.vcf.*/
          return m[0][1]
        }.into { vcfs1 ; vcfs2 }

process log_tool_version_bcftools {
    tag { "${params.project_name}.ltViB" }
    echo true
    publishDir "${params.out_dir}/${params.cohort_id}/filter-vcf", mode: 'move', overwrite: false
    label 'bcftools'

    output:
    file("tool.bcftools.version") into tool_version_bcftools

    script:
    mem = task.memory.toGiga() - 3
    """
    bcftools --version > tool.bcftools.version 2>&1
    """
}

process filter_short_snps_indels {
    tag { "${params.project_name}.${params.cohort_id}.fP" }
    publishDir "${out_dir}/${params.cohort_id}/filter-vcf", mode: 'move', overwrite: false
    label 'bcftools'
    time = 336.h    

    input:
      set val (file_name), file (vcf) from vcfs1
    output:
    set file("${filebase}.filter-pass.vcf.gz"), file("${filebase}.filter-pass.vcf.gz.tbi") into vcf_pass_out

    script:
    filebase = (file(vcf[0].baseName)).baseName
    """
    bcftools view \
    --include "FILTER='PASS'" \
    -O z \
    -o "${filebase}.filter-pass.vcf.gz" \
    ${vcf[0]} 
    bcftools index \
    -t \
    "${filebase}.filter-pass.vcf.gz"
    """
}

process filter_other {
    tag { "${params.project_name}.${params.cohort_id}.fO" }
    publishDir "${out_dir}/${params.cohort_id}/filter-vcf", mode: 'move', overwrite: false
    label 'bcftools'
    time = 336.h

    input:
      set val (file_name), file (vcf) from vcfs2
    output:
    set file("${filebase}.filter-other.vcf.gz"), file("${filebase}.filter-other.vcf.gz.tbi") into vcf_other_out

    script:
    filebase = (file(vcf[0].baseName)).baseName
    """
    bcftools view \
    --include "FILTER='.'" \
    -O z \
    -o "${filebase}.filter-other.vcf.gz" \
    ${vcf[0]}
    bcftools index \
    -t \
    "${filebase}.filter-other.vcf.gz"
    """
}


workflow.onComplete {

    println ( workflow.success ? """
        Pipeline execution summary
        ---------------------------
        Completed at: ${workflow.complete}
        Duration    : ${workflow.duration}
        Success     : ${workflow.success}
        workDir     : ${workflow.workDir}
        exit status : ${workflow.exitStatus}
        """ : """
        Failed: ${workflow.errorReport}
        exit status : ${workflow.exitStatus}
        """
    )
}
