// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process STAR_FUSION {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::star-fusion=1.10.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/star-fusion:1.10.0--hdfd78af_1"
    } else {
        container "quay.io/biocontainers/star-fusion:1.10.0--hdfd78af_1"
    }

    input:
    tuple val(meta), path(junction)
    path genome_resource_lib

    output:
    tuple val(meta), path("*.fusion_predictions.tsv")   , optional:true, emit: fusions
    path "*.version.txt"                                , emit: version

    script:
    def software            = getSoftwareName(task.process)
    def prefix              = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    def genome_resource     = genome_resource_lib ? (genome_resource_lib.exists() && file("${genome_resource_lib}/AnnotFilterRule.pm").exists()) ? "found" : "not_found" : ""

    if (genome_resource == "found") {

        """
        STAR-Fusion --genome_lib_dir $genome_resource_lib \\
            -J $junction \\
            --CPU $task.cpus
            --examine_coding_effect \\
            --output_dir . \\
            $options.args

        echo \$(STAR-Fusion --version 2>&1) | grep -i 'version' | sed 's/STAR-Fusion version: //' > ${software}.version.txt
        """
    }
    else if (genome_resource == "not_found") {

        """
        wget https://data.broadinstitute.org/Trinity/CTAT_RESOURCE_LIB/__genome_libs_StarFv1.10/GRCh38_gencode_v37_CTAT_lib_Mar012021.plug-n-play.tar.gz .
        mkdir -p $genome_resource_lib
        tar -zxf GRCh38_gencode_v37_CTAT_lib_Mar012021.plug-n-play.tar.gz --strip-components=2 -C $genome_resource_lib
        rm GRCh38_gencode_v37_CTAT_lib_Mar012021.plug-n-play.tar.gz

        STAR-Fusion --genome_lib_dir $genome_resource_lib \\
            -J $junction \\
            --CPU $task.cpus
            --examine_coding_effect \\
            --output_dir . \\
            $options.args

        echo \$(STAR-Fusion --version 2>&1) | grep -i 'version' | sed 's/STAR-Fusion version: //' > ${software}.version.txt

        """
    }
    else{

        """
        echo \$(STAR-Fusion --version 2>&1) | grep -i 'version' | sed 's/STAR-Fusion version: //' > ${software}.version.txt
        """

    }
}
