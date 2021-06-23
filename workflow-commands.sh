### Reference sources for these commands are:
#   https://github.com/passaH2O/GeoFlood/Readme.md and 
#   https://github.com/dhardestylewis/GeoFlood-Task_processor/blob/main/geoflood-task_processor/workflow_commands-geoflood_singularity.sh

# start idev node and singularity support
idev -N 1 -n 67 -t 2:00:00 -p development 	
module load tacc-singularity
 
## if needed, first remove then rebuild geoflood_docker_tacc.sif (or taudem) image in ${WORK2}
cdw2
singularity pull --disable-cache docker://dhardestylewis/geoflood_docker:tacc	
singularity pull --disable-cache docker://dhardestylewis/taudem_docker:minimal   

## only use singularity shell for GeoNet/GeoFlood commands, not TauDEM
singularity shell ./geoflood_docker_tacc.sif	
eval "$(conda shell.bash hook)"

# Set tools and project environment names
export WORKBASE='/work2/02044/arcturdk/stampede2'
# export PROJECT='TX-Counties-Travis-120902050406'    ## HUC12 test dataset
# export WORKBRANCH="${WORKBASE}/GeoFlood"     ## use for test projects
export WORKBRANCH="${WORKBASE}/TxDOT_GeoFlood/BMT-Beaumont"
export PROJECT='BMT110_ColeCreek'
export WORKING_DIR="${WORKBRANCH}/${PROJECT}"    
export TASKPROC="${WORKBASE}/GeoFlood-taskprocessor"
export DOCKERSIF="${WORKBASE}/geoflood_docker_tacc.sif"
export DOCKERTAU="${WORKBASE}/taudem_docker_minimal.sif"
export GEOTOOLS="${WORKBASE}/GeoFlood/Tools_tacc"
export TAUDEM='/opt/taudem/bin'     ## works within Singularity shell
export PROJECT_CFG="${WORKING_DIR}/GeoFlood_${PROJECT}.cfg"
export GEOINPUTS="${WORKING_DIR}/GeoInputs"
export GEOOUTPUTS="${WORKING_DIR}/GeoOutputs"
export LOCATION_NAME="${PROJECT}"

# make sure conda env is set to geoflood except for grass step
conda activate geoflood

## GeoNet - Configure and prepare file structure
# ... override default input & output folder names
# python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk --input_dir Inputs --output_dir Outputs 
# ... assume the input and output folders are called GeoInputs, GeoOutputs
python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk
python ${GEOTOOLS}/GeoNet/pygeonet_prepare.py

# GeoNet steps 1-2. DEM smoothing, slope & curvature
python ${GEOTOOLS}/GeoNet/pygeonet_nonlinear_filter.py
python ${GEOTOOLS}/GeoNet/pygeonet_slope_curvature.

# GeoNet step 3. GRASS GIS
# This needs to run in its own conda env, first deactivate geoflood
conda deactivate 
conda activate grass
  python ${GEOTOOLS}/GeoNet/pygeonet_grass_py3.py
conda deactivate 
conda activate geoflood

# GeoNet step 4. Flow accum & curvature skeleton
python ${GEOTOOLS}/GeoNet/pygeonet_skeleton_definition.py

## GeoFlood step 6. network node reading - make sure Catchment.shp, Flowline.shp are in ${GEOINPUTS}/GIS/${PROJECT}   
python ${GEOTOOLS}/GeoFlood/Network_Node_Reading.py
### next edit the endPoints.csv file at "${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_endPoints.csv"
cd ${GEOOUTPUTS}/GIS/${PROJECT}

# GeoFlood steps 7. Negative HAND, and 8. Network Extraction
python ${GEOTOOLS}/GeoFlood/Relative_Height_Estimation.py
python ${GEOTOOLS}/GeoFlood/Network_Extraction.py

## TauDEM step 9. pit-filling, 10. D-Infinity flow direction, and 12. HAND
# exit singularity container
module load mvapich2
# ibrun -np 1 singularity run ${DOCKERTAU} ${TAUDEM}/pitremove -z ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif 
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/pitremove -z ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/dinfflowdir -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif 
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/dinfdistdown -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif -src ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_path.tif -dd ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_hand.tif -m ave v 

#### fine
