### Reference sources for these commands are:
#   https://github.com/passaH2O/GeoFlood/Readme.md and 
#   https://github.com/dhardestylewis/GeoFlood-Task_processor/blob/main/geoflood-task_processor/workflow_commands-geoflood_singularity.sh

# Set tools and project environment names
# export PROJECT='BMT110_ColeCreek'
# export WORKING_DIR="/work2/02044/arcturdk/stampede2/TxDOT_GeoFlood/${PROJECT}"
export PROJECT='TX-Counties-Travis-120902050406'
export WORKING_DIR="/work2/02044/arcturdk/stampede2/${PROJECT}"
export PROJECT_CFG="${WORKING_DIR}/GeoFlood_${PROJECT}.cfg"
export TASKPROC='/work2/02044/arcturdk/stampede2/GeoFlood-taskprocessor'
export PATH_DOCKERSIF='/work2/02044/arcturdk/stampede2/geoflood_docker_latest.sif'
export PATH_GEOTOOLS='/work2/02044/arcturdk/stampede2/GeoFlood/Tools_tacc'
export PATH_TAUDEM='/usr/local/taudem/'
export PATH_GEOINPUTS="${WORKING_DIRECTORY}/GeoInputs"
export PATH_GEOOUTPUTS="${WORKING_DIRECTORY}/GeoOutputs"
export LOCATION_NAME="${PROJECT}"

## GeoNet - Configure and prepare file structure
# ... override default input & output folder names
# python ${PATH_GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk --input_dir Inputs --output_dir Outputs 
# ... assume the input and output folders are called GeoInputs, GeoOutputs
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_prepare.py

# GeoNet steps 1-4. DEM smoothing, slope & curvature, GRASS GIS, flow accum & curvature skeleton
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_nonlinear_filter.py
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_slope_curvature.py
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_grass_py3.py
python ${PATH_GEOTOOLS}/GeoNet/pygeonet_skeleton_definition.py

## GeoFlood step 6. network node reading - make sure Catchment.shp, Flowline.shp are in ${PATH_GEOINPUTS}/GIS/${PROJECT}   
python ${PATH_GEOTOOLS}/GeoFlood/Network_Node_Reading.py
### next edit the endPoints.csv file at "${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_endPoints.csv"

# GeoFlood steps 7. Negative HAND, and 8. Network Extraction:wq
python ${PATH_GEOTOOLS}/GeoFlood/Relative_Height_Estimation.py
python ${PATH_GEOTOOLS}/GeoFlood/Network_Extraction.py

## TauDEM step 9. pit-filling
# mpiexec -n 66 ${TAUDEM}/pitremove -z ${PATH_GEOINPUTS}/GIS/${PROJECT}.tif -fel ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_fel.tif
ibrun -np 1 singularity run ${PATH_DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "pitremove -z ${PATH_GEOINPUTS}/GIS/${PROJECT}.tif -fel ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_fel.tif" 
gdal_translate -a_srs $(gdalsrsinfo -e ${PATH_GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel_srs.tif 
mv ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel_srs.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif 

# TauDEM step 10. D-Infinity flow direction
# mpiexec -n 66 ${TAUDEM}/dinfflowdir> - fel ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_fel.tif> -ang ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_ang.tif> -slp ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_slp.tif>
ibrun -np 67 singularity run ${PATH_DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "dinfflowdir -ang ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif" 
gdal_translate -a_srs $(gdalsrsinfo -e ${PATH_GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang_srs.tif 
mv ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang_srs.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif 
gdal_translate -a_srs $(gdalsrsinfo -e ${PATH_GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp_srs.tif 
mv ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp_srs.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif 

# TauDEM step 12. HAND
# mpiexec -n 66 ${TAUDEM}/dinfdistdown> - ang ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_ang.tif> -fel ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_fel.tif> -slp ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_slp.tif> -src ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_path.tif> -dd ${PATH_GEOOUTPUTS}/GIS/${PROJECT}_hand.tif> -m ave v
ibrun -np 67 singularity run ${PATH_DOCKERSIF} ${TASKPROC}/container_wrapper.sh --environment geoflood --command "areadinf -ang ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -sca ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif" 
gdal_translate -a_srs $(gdalsrsinfo -e ${PATH_GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif | head -n2 | tail -n1) ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca_srs.tif 
mv ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca_srs.tif ${PATH_GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_sca.tif 