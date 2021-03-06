CMAKE_MINIMUM_REQUIRED(VERSION 2.8 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.8)

set(CMAKE_BUILD_TYPE Release)

find_package(OpenMP)
if (OPENMP_FOUND)
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS} -fopenmp")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS} -fopenmp")
endif()

FIND_PACKAGE(Torch REQUIRED)
FIND_PACKAGE(CUDA 7.5 REQUIRED)

IF(DEFINED Torch_INSTALL_INCLUDE)
  SET(TH_INSTALL_INCLUDE ${Torch_INSTALL_INCLUDE})
  SET(TH_INSTALL_LIB ${Torch_INSTALL_LIB})
ENDIF()

INCLUDE_DIRECTORIES(
  ${TH_INSTALL_INCLUDE}/TH
  ${TH_INSTALL_INCLUDE}
)
INCLUDE_DIRECTORIES("${Torch_INSTALL_INCLUDE}/THC")

LINK_DIRECTORIES(${TH_INSTALL_LIB})

add_definitions(-std=c++11 -fPIC)
LIST(APPEND CUDA_NVCC_FLAGS "-arch=sm_20 -Xcompiler -fPIC")
LINK_DIRECTORIES("${Torch_INSTALL_LIB}")



#TH_MATH: tensor scaling, rotating and saving to ccp4
include_directories("Math")
add_subdirectory(Math)

#PROTEINLOADER: protein loading library
include_directories("CppProteinLoader")
add_subdirectory(CppProteinLoader)


# library for loading protein structure from torch
ADD_LIBRARY(load_protein SHARED CppProteinLoader/loadProtein.cpp)
TARGET_LINK_LIBRARIES(load_protein TH PROTEINLOADER)

CUDA_ADD_LIBRARY(load_protein_cuda SHARED CppProteinLoader/loadProteinCUDA.cu)
TARGET_LINK_LIBRARIES(load_protein_cuda TH THC PROTEINLOADER)

CUDA_ADD_LIBRARY(get_gradient_cuda SHARED CppProteinLoader/reprojectGradientCUDA.cu)
TARGET_LINK_LIBRARIES(get_gradient_cuda TH THC PROTEINLOADER)

CUDA_ADD_LIBRARY(load_protein_cuda_direct SHARED CppProteinLoader/loadProteinCUDAdirect.cu)
TARGET_LINK_LIBRARIES(load_protein_cuda_direct TH THC PROTEINLOADER)
