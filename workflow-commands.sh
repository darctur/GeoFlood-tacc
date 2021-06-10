### Reference sources for these commands are:
#   https://github.com/passaH2O/GeoFlood/Readme.md and 
#   https://github.com/dhardestylewis/GeoFlood-Task_processor/blob/main/geoflood-task_processor/workflow_commands-geoflood_singularity.sh

# Set tools and project environment names
export WORKBASE='/work2/02044/arcturdk/stampede2'
export PROJECT='TX-Counties-Travis-120902050406'    ## small test dataset
export WORKBRANCH="${WORKBASE}/GeoFlood"     ## use for test projects
# export WORKBRANCH="${WORKBASE}/TxDOT_GeoFlood/BMT-Beaumont"
# export PROJECT='BMT110-ColeCreek'
export WORKING_DIR="${WORKBRANCH}/${PROJECT}"    
export TASKPROC="${WORKBASE}/GeoFlood-taskprocessor"
export DOCKERSIF="${WORKBASE}/geoflood_docker_latest.sif"
export GEOTOOLS="${WORKBASE}/GeoFlood/Tools_tacc"
export TAUDEM='/usr/local/taudem/'     ## works within Singularity shell
export PROJECT_CFG="${WORKING_DIR}/GeoFlood_${PROJECT}.cfg"
export GEOINPUTS="${WORKING_DIR}/GeoInputs"
export GEOOUTPUTS="${WORKING_DIR}/GeoOutputs"
export LOCATION_NAME="${PROJECT}"

## GeoNet - Configure and prepare file structure
# ... override default input & output folder names
# python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk --input_dir Inputs --output_dir Outputs 
# ... assume the input and output folders are called GeoInputs, GeoOutputs
python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk
python ${GEOTOOLS}/GeoNet/pygeonet_prepare.py

# GeoNet steps 1-4. DEM smoothing, slope & curvature, GRASS GIS, flow accum & curvature skeleton
python ${GEOTOOLS}/GeoNet/pygeonet_nonlinear_filter.py
python ${GEOTOOLS}/GeoNet/pygeonet_slope_curvature.py
python ${GEOTOOLS}/GeoNet/pygeonet_grass_py3.py
python ${GEOTOOLS}/GeoNet/pygeonet_skeleton_definition.py

## GeoFlood step 6. network node reading - make sure Catchment.shp, Flowline.shp are in ${GEOINPUTS}/GIS/${PROJECT}   
python ${GEOTOOLS}/GeoFlood/Network_Node_Reading.py
### next edit the endPoints.csv file at "${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_endPoints.csv"

# GeoFlood steps 7. Negative HAND, and 8. Network Extraction
python ${GEOTOOLS}/GeoFlood/Relative_Height_Estimation.py
python ${GEOTOOLS}/GeoFlood/Network_Extraction.py

## TauDEM step 9. pit-filling
# mpiexec -n 66 ${TAUDEM}/pitremove -z ${GEOINPUTS}/GIS/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}_fel.tif
ibrun -np 1 singularity run ${DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "pitremove -z ${GEOINPUTS}/GIS/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}_fel.tif" 
# gdal_translate -a_srs $(gdalsrsinfo -e ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel_srs.tif 
# mv ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel_srs.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif 

# TauDEM step 10. D-Infinity flow direction
# mpiexec -n 66 ${TAUDEM}/dinfflowdir> - fel ${GEOOUTPUTS}/GIS/${PROJECT}_fel.tif> -ang ${GEOOUTPUTS}/GIS/${PROJECT}_ang.tif> -slp ${GEOOUTPUTS}/GIS/${PROJECT}_slp.tif>
ibrun -np 67 singularity run ${DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "dinfflowdir -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif" 
# gdal_translate -a_srs $(gdalsrsinfo -e ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang_srs.tif 
# mv ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang_srs.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif 
# gdal_translate -a_srs $(gdalsrsinfo -e ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp_srs.tif 
# mv ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp_srs.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif 

# TauDEM step 12. HAND
# mpiexec -n 66 ${TAUDEM}/dinfdistdown> - ang ${GEOOUTPUTS}/GIS/${PROJECT}_ang.tif> -fel ${GEOOUTPUTS}/GIS/${PROJECT}_fel.tif> -slp ${GEOOUTPUTS}/GIS/${PROJECT}_slp.tif> -src ${GEOOUTPUTS}/GIS/${PROJECT}_path.tif> -dd ${GEOOUTPUTS}/GIS/${PROJECT}_hand.tif> -m ave v
ibrun -np 67 singularity run ${DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "areadinf -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -sca ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif" 
# gdal_translate -a_srs $(gdalsrsinfo -e ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca_srs.tif 
# mv ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca_srs.tif ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif 
