### Reference sources for these commands are:
#   https://github.com/passaH2O/GeoFlood/Readme.md and 
#   https://github.com/dhardestylewis/GeoFlood-Task_processor/blob/main/geoflood-task_processor/workflow_commands-geoflood_singularity.sh

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

## GeoNet - Configure and prepare file structure
# ... override default input & output folder names
# python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk --input_dir Inputs --output_dir Outputs 
# ... assume the input and output folders are called GeoInputs, GeoOutputs
python ${GEOTOOLS}/GeoNet/pygeonet_configure.py -dir ${WORKING_DIR} -p ${PROJECT} -n ${PROJECT} --no_chunk
python ${GEOTOOLS}/GeoNet/pygeonet_prepare.py

# GeoNet steps 1-2. DEM smoothing, slope & curvature
python ${GEOTOOLS}/GeoNet/pygeonet_nonlinear_filter.py
python ${GEOTOOLS}/GeoNet/pygeonet_slope_curvature.py

# GeoNet step 3. GRASS GIS
# There are five major modules that are included with the GDAL Python bindings:
from osgeo import gdal
from osgeo import ogr
from osgeo import osr
from osgeo import gdal_array
from osgeo import gdalconst
# Additionally, there are five compatibility modules that are included but provide notices to state that they are deprecated and will be going away. 
# If you are using GDAL 1.7 bindings, you should update your imports to utilize the usage above, but the following will work until GDAL 3.1.
import gdal
import ogr
import osr
import gdalnumeric
import gdalconst
# 
python ${GEOTOOLS}/GeoNet/pygeonet_grass_py3.py

# GeoNet step 4. Flow accum & curvature skeleton
python ${GEOTOOLS}/GeoNet/pygeonet_skeleton_definition.py

## GeoFlood step 6. network node reading - make sure Catchment.shp, Flowline.shp are in ${GEOINPUTS}/GIS/${PROJECT}   
python ${GEOTOOLS}/GeoFlood/Network_Node_Reading.py
### next edit the endPoints.csv file at "${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_endPoints.csv"

# GeoFlood steps 7. Negative HAND, and 8. Network Extraction
python ${GEOTOOLS}/GeoFlood/Relative_Height_Estimation.py
python ${GEOTOOLS}/GeoFlood/Network_Extraction.py

module load mvapich2
## TauDEM step 9. pit-filling, 10. D-Infinity flow direction, and 12. HAND
# ibrun -np 1 singularity run ${DOCKERTAU} ${TAUDEM}/pitremove -z ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif 
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/pitremove -z ${GEOINPUTS}/GIS/${PROJECT}/${PROJECT}.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/dinfflowdir -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif 
ibrun -np 67 singularity run ${DOCKERTAU} ${TAUDEM}/dinfdistdown -ang ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_ang.tif -fel ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_fel.tif -slp ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_slp.tif -src ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_path.tif -dd ${GEOOUTPUTS}/GIS/${PROJECT}/${PROJECT}_hand.tif -m ave v 

#### fine
