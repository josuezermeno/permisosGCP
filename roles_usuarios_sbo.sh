#!/bin/bash

#PROJECTS=($(gcloud projects list --format="value(projectId)"))

declare -a PROJECTS_15=(

    "spin-datalake-prd-trusted"
    "spin-datalake-prd-refined"
    "spin-datalake-prd-landing"
    "spin-datalake-prd-raw"
    "spin-datalake-dev-trusted"
    "spin-datalake-dev-refined"
    "spin-datalake-dev-landing"
    "spin-datalake-dev-raw"
    "spin-datalake-qas-trusted"
    "spin-datalake-qas-refined"
    "spin-datalake-qas-landing"
    "spin-datalake-qas-raw"
    "spin-instances-prod"
    "spin-instances-psb"
    "spin-instances-dev"
    "spin-bigquery-dev"
    "spin-bigquery-prod"
    "spin-datasharing-prd"
    "spin-datasharing-qas"
    "spin-datasharing-dev"
    "spin-instances-qa"
    "spin-data-analytics"
    "spin-bigquery-qas"
    "spin-bigquery-qa"
)

declare -a PROJECTS_custom=(

    
     "spin-datalake-prd-trusted"
    "spin-datalake-prd-refined"
    "spin-datalake-prd-landing"
    "spin-datalake-prd-raw"
    "spin-datalake-dev-trusted"
    "spin-datalake-dev-refined"
    "spin-datalake-dev-landing"
    "spin-datalake-dev-raw"
    "spin-datalake-qas-trusted"
    "spin-datalake-qas-refined"
    "spin-datalake-qas-landing"
    "spin-datalake-qas-raw"
    "spin-instances-prod"
    "spin-instances-psb"
    "spin-instances-dev"
    "spin-bigquery-dev"
    "spin-bigquery-prod"
    "spin-datasharing-prd"
    "spin-datasharing-qas"
    "spin-datasharing-dev"
    "spin-instances-qa"
    "spin-data-analytics"
    "spin-bigquery-qas"
    "spin-bigquery-qa"
     "spin-dp-raw-prod"
    "spin-dp-raw-qa"
    "spin-dp-raw-dev"
    "spin-dp-raw-sb-dev"
    "spin-dp-raw-sb-qa"
    "spin-dp-refined-prod"
    "spin-dp-refined-qa"
    "spin-dp-refined-dev"
    "spin-dp-refined-sb-dev"
    "spin-dp-refined-sb-qa"
    "spin-dp-landing-prod"
    "spin-dp-landing-qa"
    "spin-dp-landing-dev"
    "spin-dp-landing-sb-dev"
    "spin-dp-landing-sb-qa"
    "spin-dp-trusted-prod"
    "spin-dp-trusted-qa"
    "spin-dp-trusted-dev"
    "spin-dp-trusted-sb-dev"
    "spin-dp-trusted-sb-qa"
    "spin-dp-semantic-layer-dev"
    "spin-dp-semantic-layer-prod"
    "spin-dp-semantic-layer-qa"
    "spin-dp-management-prod"
    "spin-dp-management-qa"
    "spin-dp-management-dev"
    "spin-dp-management-sb-dev"
    "spin-dp-management-sb-qa"
    "spin-dp-compute-dev"
    "spin-dp-compute-prod"
    "spin-dp-compute-qa"
    "spin-dp-compute-sb-dev"
    "spin-dp-compute-sb-qa"
    "spin-dp-sandbox"     
    "spin-dp-datasharing-prod"
    "spin-dp-datasharing-dev"
    "spin-dp-datasharing-qa"  
    "spin-aip-singularity-comp-prd"
    "spin-aip-singularity-comp-sb"
    "spin-aip-singularity-comp-stg"
    "spin-aip-singularity-data-prd"
    "spin-aip-singularity-data-sb"
    "spin-aip-singularity-data-stg"    

)

declare -a PROJECTS_20=(
    "spin-dp-raw-prod"
    "spin-dp-raw-qa"
    "spin-dp-raw-dev"
    "spin-dp-raw-sb-dev"
    "spin-dp-raw-sb-qa"
    "spin-dp-refined-prod"
    "spin-dp-refined-qa"
    "spin-dp-refined-dev"
    "spin-dp-refined-sb-dev"
    "spin-dp-refined-sb-qa"
    "spin-dp-landing-prod"
    "spin-dp-landing-qa"
    "spin-dp-landing-dev"
    "spin-dp-landing-sb-dev"
    "spin-dp-landing-sb-qa"
    "spin-dp-trusted-prod"
    "spin-dp-trusted-qa"
    "spin-dp-trusted-dev"
    "spin-dp-trusted-sb-dev"
    "spin-dp-trusted-sb-qa"
    "spin-dp-semantic-layer-dev"
    "spin-dp-semantic-layer-prod"
    "spin-dp-semantic-layer-qa"
    "spin-dp-management-prod"
    "spin-dp-management-qa"
    "spin-dp-management-dev"
    "spin-dp-management-sb-dev"
    "spin-dp-management-sb-qa"
    "spin-dp-compute-dev"
    "spin-dp-compute-prod"
    "spin-dp-compute-qa"
    "spin-dp-compute-sb-dev"
    "spin-dp-compute-sb-qa"
    "spin-dp-sandbox"     
    "spin-dp-datasharing-prod"
    "spin-dp-datasharing-dev"
    "spin-dp-datasharing-qa"    
)

declare -a PROJECTS_Sing=( 
    "spin-aip-singularity-comp-prd"
    "spin-aip-singularity-comp-sb"
    "spin-aip-singularity-comp-stg"
    "spin-aip-singularity-data-prd"
    "spin-aip-singularity-data-sb"
    "spin-aip-singularity-data-stg"      
)


echo 'Project,Role,Type,Email' >  users_roles_sbo.csv  
 





#PROJECTS
for PROJECT in "${PROJECTS_custom[@]}"
#Proyecto="$PROJECT"

do 
    echo "Procesando proyecto " $PROJECT
    

      NoRoles="`gcloud projects get-iam-policy $PROJECT --format=json | grep "role" | wc -l`"

      positionRoles=0
  
      if [ "${NoRoles}" -ge 1 ] 
      then
      
          for ((i=0; i<${NoRoles}; i++)); do
                
                
                Rol="`gcloud projects get-iam-policy $PROJECT --flatten="bindings[$i].role" --format=object`"
                
               # if [ ${#Rol} -ne 4 ]
               #then
               #    break
               #fi

                echo "Procesando Rol " $Rol                
                for ((k=0; k<500; k++)); do                                   
                    Miembro="`gcloud projects get-iam-policy $PROJECT --flatten="bindings[$i].members[$k]" --format=object `"    
                 
                    tiporol=${Rol:0:5}                    
                    std="roles"

                    if [ "$tiporol" == "$std" ]                #para saber si es un rol estandar o custom        
                    then 
                        role=${Rol:6:50}
                    else 
                        role=${Rol:33:150}      
                    fi   
                    

                    if [ "${Miembro:0:1}"  == "u" ]                #para saber que tipo de usuario es
                    then #user
                        TipoUsuario="User"
                        usuario=${Miembro:5:100}
                    elif [ "${Miembro:0:1}"  == "s" ]
                    then
                        TipoUsuario="Service Account"
                        #echo "miembro es SA"
                        usuario=${Miembro:15:100}
                    elif [ "${Miembro:0:1}"  == "g" ]
                    then
                        TipoUsuario="Group"
                        #echo "miembro es grupo"
                        usuario=${Miembro:6:200}   

                    else
                        break
                    fi 


                    
                    if [ ${#Miembro} -ne 4 ] #validamos si tiene encontró mas miembros, si no se sale
                    then                   
                        echo  "$PROJECT","$role","$TipoUsuario","$usuario"   >>  users_roles_sbo.csv                      
                    else
                        break                        
                    fi
                
                done	
                
            done	



     
     fi




done