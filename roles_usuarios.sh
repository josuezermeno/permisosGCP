#!/bin/bash

#PROJECTS=($(gcloud projects list --format="value(projectId)"))

declare -a PROJECTS_15=(

    "daf-datalake-prd-trusted"
    "daf-datalake-prd-refined"
    "daf-datalake-prd-landing"
    "daf-datalake-prd-raw"
    "daf-datalake-dev-trusted"
    "daf-datalake-dev-refined"
    "daf-datalake-dev-landing"
    "daf-datalake-dev-raw"
    "daf-datalake-qas-trusted"
    "daf-datalake-qas-refined"
    "daf-datalake-qas-landing"
    "daf-datalake-qas-raw"
    "daf-instances-prod"
    "daf-instances-psb"
    "daf-instances-dev"
    "daf-bigquery-dev"
    "daf-bigquery-prod"
    "daf-datasharing-prd"
    "daf-datasharing-qas"
    "daf-datasharing-dev"
    "daf-instances-qa"
    "daf-data-analytics"
    "daf-bigquery-qas"
    "daf-bigquery-qa"
)

declare -a PROJECTS_all=( 
    "daf-aip-singularity-comp-prd"
    "daf-aip-singularity-comp-sb"
    "daf-aip-singularity-comp-stg"
    "daf-aip-singularity-data-prd"
    "daf-aip-singularity-data-sb"
    "daf-aip-singularity-data-stg"  
    "daf-dp-raw-prod"
    "daf-dp-raw-qa"
    "daf-dp-raw-dev"
    "daf-dp-raw-sb-dev"
    "daf-dp-raw-sb-qa"
    "daf-dp-refined-prod"
    "daf-dp-refined-qa"
    "daf-dp-refined-dev"
    "daf-dp-refined-sb-dev"
    "daf-dp-refined-sb-qa"
    "daf-dp-landing-prod"
    "daf-dp-landing-qa"
    "daf-dp-landing-dev"
    "daf-dp-landing-sb-dev"
    "daf-dp-landing-sb-qa"
    "daf-dp-trusted-prod"
    "daf-dp-trusted-qa"
    "daf-dp-trusted-dev"
    "daf-dp-trusted-sb-dev"
    "daf-dp-trusted-sb-qa"
    "daf-dp-semantic-layer-dev"
    "daf-dp-semantic-layer-prod"
    "daf-dp-semantic-layer-qa"
    "daf-dp-management-prod"
    "daf-dp-management-qa"
    "daf-dp-management-dev"
    "daf-dp-management-sb-dev"
    "daf-dp-management-sb-qa"
    "daf-dp-compute-dev"
    "daf-dp-compute-prod"
    "daf-dp-compute-qa"
    "daf-dp-compute-sb-dev"
    "daf-dp-compute-sb-qa"
    "daf-dp-sandbox"     
    "daf-dp-datasharing-prod"
    "daf-dp-datasharing-dev"
    "daf-dp-datasharing-qa"       
)

declare -a PROJECTS_custom=(

    
     "daf-datalake-prd-trusted"
    "daf-datalake-prd-refined"
    "daf-datalake-prd-landing"
    "daf-datalake-prd-raw"
    "daf-datalake-dev-trusted"
    "daf-datalake-dev-refined"
    "daf-datalake-dev-landing"
    "daf-datalake-dev-raw"
    "daf-datalake-qas-trusted"
    "daf-datalake-qas-refined"
    "daf-datalake-qas-landing"
    "daf-datalake-qas-raw"
    "daf-instances-prod"
    "daf-instances-psb"
    "daf-instances-dev"
    "daf-bigquery-dev"
    "daf-bigquery-prod"
    "daf-datasharing-prd"
    "daf-datasharing-qas"
    "daf-datasharing-dev"
    "daf-instances-qa"
    "daf-data-analytics"
    "daf-bigquery-qas"
    "daf-bigquery-qa"
     "daf-dp-raw-prod"
    "daf-dp-raw-qa"
    "daf-dp-raw-dev"
    "daf-dp-raw-sb-dev"
    "daf-dp-raw-sb-qa"
    "daf-dp-refined-prod"
    "daf-dp-refined-qa"
    "daf-dp-refined-dev"
    "daf-dp-refined-sb-dev"
    "daf-dp-refined-sb-qa"
    "daf-dp-landing-prod"
    "daf-dp-landing-qa"
    "daf-dp-landing-dev"
    "daf-dp-landing-sb-dev"
    "daf-dp-landing-sb-qa"
    "daf-dp-trusted-prod"
    "daf-dp-trusted-qa"
    "daf-dp-trusted-dev"
    "daf-dp-trusted-sb-dev"
    "daf-dp-trusted-sb-qa"
    "daf-dp-semantic-layer-dev"
    "daf-dp-semantic-layer-prod"
    "daf-dp-semantic-layer-qa"
    "daf-dp-management-prod"
    "daf-dp-management-qa"
    "daf-dp-management-dev"
    "daf-dp-management-sb-dev"
    "daf-dp-management-sb-qa"
    "daf-dp-compute-dev"
    "daf-dp-compute-prod"
    "daf-dp-compute-qa"
    "daf-dp-compute-sb-dev"
    "daf-dp-compute-sb-qa"
    "daf-dp-sandbox"     
    "daf-dp-datasharing-prod"
    "daf-dp-datasharing-dev"
    "daf-dp-datasharing-qa"  
    "daf-aip-singularity-comp-prd"
    "daf-aip-singularity-comp-sb"
    "daf-aip-singularity-comp-stg"
    "daf-aip-singularity-data-prd"
    "daf-aip-singularity-data-sb"
    "daf-aip-singularity-data-stg"    

)

declare -a PROJECTS_20=(
    "daf-dp-raw-prod"
    "daf-dp-raw-qa"
    "daf-dp-raw-dev"
    "daf-dp-raw-sb-dev"
    "daf-dp-raw-sb-qa"
    "daf-dp-refined-prod"
    "daf-dp-refined-qa"
    "daf-dp-refined-dev"
    "daf-dp-refined-sb-dev"
    "daf-dp-refined-sb-qa"
    "daf-dp-landing-prod"
    "daf-dp-landing-qa"
    "daf-dp-landing-dev"
    "daf-dp-landing-sb-dev"
    "daf-dp-landing-sb-qa"
    "daf-dp-trusted-prod"
    "daf-dp-trusted-qa"
    "daf-dp-trusted-dev"
    "daf-dp-trusted-sb-dev"
    "daf-dp-trusted-sb-qa"
    "daf-dp-semantic-layer-dev"
    "daf-dp-semantic-layer-prod"
    "daf-dp-semantic-layer-qa"
    "daf-dp-management-prod"
    "daf-dp-management-qa"
    "daf-dp-management-dev"
    "daf-dp-management-sb-dev"
    "daf-dp-management-sb-qa"
    "daf-dp-compute-dev"
    "daf-dp-compute-prod"
    "daf-dp-compute-qa"
    "daf-dp-compute-sb-dev"
    "daf-dp-compute-sb-qa"
    "daf-dp-sandbox"     
    "daf-dp-datasharing-prod"
    "daf-dp-datasharing-dev"
    "daf-dp-datasharing-qa"    
)

declare -a PROJECTS_Sing=( 
    "daf-aip-singularity-comp-prd"
    "daf-aip-singularity-comp-sb"
    "daf-aip-singularity-comp-stg"
    "daf-aip-singularity-data-prd"
    "daf-aip-singularity-data-sb"
    "daf-aip-singularity-data-stg"      
)

declare -a ORGANIZATIONS=( 
    "713468743428"
    "532450477381"
)





echo 'Project,Role,Type,Email' >  users_roles_global.csv  

echo 'Project,Role,Type,Email' >  users_roles_orgs.csv  


#organization



for PROJECT in "${ORGANIZATIONS[@]}"
#Proyecto="$PROJECT"

do 
    echo "Procesando proyecto " $PROJECT
    

      NoRoles="`gcloud organizations get-iam-policy $PROJECT --format=json | grep "role" | wc -l`"

      positionRoles=0
  
      if [ "${NoRoles}" -ge 1 ] 
      then
      
          for ((i=0; i<${NoRoles}; i++)); do
                
                
                Rol="`gcloud organizations get-iam-policy $PROJECT --flatten="bindings[$i].role" --format=object`"
                
               # if [ ${#Rol} -ne 4 ]
               #then
               #    break
               #fi

                echo "Procesando Rol " $Rol                
                for ((k=0; k<500; k++)); do                                   
                    Miembro="`gcloud organizations get-iam-policy $PROJECT --flatten="bindings[$i].members[$k]" --format=object `"    
                 
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
                        echo  "$PROJECT","$role","$TipoUsuario","$usuario"   >>  users_roles_orgs.csv                      
                    else
                        break                        
                    fi
                
                done	
                
            done	



     
     fi




done


#PROJECTS
for PROJECT in "${PROJECTS_all[@]}"
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
                        echo  "$PROJECT","$role","$TipoUsuario","$usuario"   >>  users_roles_global.csv                      
                    else
                        break                        
                    fi
                
                done	
                
            done	



     
     fi




done