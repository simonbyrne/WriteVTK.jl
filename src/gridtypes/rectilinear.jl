# Included in WriteVTK.jl.

immutable RectilinearFile <: DatasetFile
    xdoc::XMLDocument
    path::UTF8String
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (or written inline, base64-encoded?)
    buf::IOBuffer       # Buffer with appended data.
    function RectilinearFile(xdoc, path, Npts, compressed, appended)
        gridType_str = "RectilinearGrid"
        if appended
            buf = IOBuffer()
        else
            buf = IOBuffer(0)
            close(buf)
        end
        return new(xdoc, path, gridType_str, Npts, compressed,
                   appended, buf)
    end
end


function vtk_grid{T<:FloatingPoint}(
    filename_noext::AbstractString,
    x::Array{T,1}, y::Array{T,1}, z::Array{T,1};
    compress::Bool=true, append::Bool=true)

    xvtk = XMLDocument()

    Ni, Nj, Nk = length(x), length(y), length(z)
    Npts = Ni*Nj*Nk
    vtk = RectilinearFile(xvtk, filename_noext*".vtr", Npts,
                          compress, append)

    # TODO create a xml_write_header, that is common to all grid types,
    # to reduce duplicate code.

    # VTKFile node
    xroot = create_root(xvtk, "VTKFile")
    set_attribute(xroot, "type",    vtk.gridType_str)
    set_attribute(xroot, "version", "1.0")
    set_attribute(xroot, "byte_order", "LittleEndian")
    if vtk.compressed
        set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
        set_attribute(xroot, "header_type", "UInt32")
    end

    # RectilinearGrid node
    xGrid = new_child(xroot, vtk.gridType_str)
    extent = "1 $Ni 1 $Nj 1 $Nk"
    set_attribute(xGrid, "WholeExtent", extent)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", extent)

    # Coordinates node
    xPoints = new_child(xPiece, "Coordinates")

    # DataArray node
    data_to_xml(vtk, xPoints, x, 1, "x")
    data_to_xml(vtk, xPoints, y, 1, "y")
    data_to_xml(vtk, xPoints, z, 1, "z")

    return vtk::RectilinearFile
end


# Multiblock variant of vtk_grid.
function vtk_grid{T}(vtm::MultiblockFile,
                     x::Array{T,1}, y::Array{T,1}, z::Array{T,1};
                     compress::Bool=true, append::Bool=true)
    path_base = splitext(vtm.path)[1]
    vtkFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtkFilename_noext, x, y, z;
                   compress=compress, append=append)
    multiblock_add_block(vtm, vtk)
    return vtk::DatasetFile
end
