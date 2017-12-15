vtk_module(vtkIOCore
  GROUPS
    StandAlone
  TEST_DEPENDS
    vtkTestingCore
  KIT
    vtkIO
  DEPENDS
    vtkCommonCore
    vtkCommonExecutionModel
  PRIVATE_DEPENDS
    vtkCommonDataModel
    vtkCommonMisc
    vtklz4
    vtksys
    vtkutf8
    vtkzlib
  )
