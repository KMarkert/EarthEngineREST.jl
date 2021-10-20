# script to add EarthEngine REST API types
# attempt to replicated API types in Julia structs

"""
`EESession` type used for authenticating request to the API

$(TYPEDFIELDS)
"""
struct EESession
    "GCP project name used for REST API requests"
    project::AbstractString
    "authenticated Python requests session for making requests"
    auth::PyObject

    EESession(project::AbstractString, auth::PyObject) = new(project, auth)

    function EESession(args...; kwargs...)
        try
            copy!(serviceaccount, pyimport("google.oauth2.service_account"))
        catch err
            error(
                "The `google.oauth2` package could not be imported. You must install the Python earthengine-api before using this package. The error was $err",
            )
        end

        try
            copy!(gauth, pyimport("google.auth.transport.requests"))
        catch err
            error(
                "The `google.auth` package could not be imported. You must install the Python earthengine-api before using this package. The error was $err",
            )
        end

        credentials = serviceaccount.Credentials.from_service_account_file(
            args...;
            kwargs...,
        )
        scoped_credentials = credentials.with_scopes([
            "https://www.googleapis.com/auth/cloud-platform",
        ])
        auth = gauth.AuthorizedSession(scoped_credentials)
        project = credentials.project_id
        new(project, auth)
    end
end


"""
Type used for defining the number of rows and columns for image requests
See https://developers.google.com/earth-engine/reference/rest/v1beta/PixelGrid#GridDimensions

$(TYPEDFIELDS)
"""
struct GridDimensions
    "width of the grid, in pixels"
    width::Integer
    "height of the grid, in pixels"
    height::Integer

    GridDimensions(width::Integer, height::Integer) = new(width, height)
end

"""
Type for defining the affine transform of image requests. The six values form a 2x3 matrix:

See https://developers.google.com/earth-engine/reference/rest/v1beta/PixelGrid#affinetransform

"""
struct AffineTransform
    "horizontal scale factor. w-e pixel resolution / pixel width"
    scaleX::Real
    "horizontal shear factor. row rotation typically set to 0 for north-up images"
    shearX::Real
    "horizontal offset. x-coordinate of the upper-left corner of the upper-left pixel "
    translateX::Real
    "vertical shear factor. column rotation typically set to 0 for north-up images"
    shearY::Real
    "vertical scale factor. n-s pixel resolution / pixel height (negative for north-up images)"
    scaleY::Real
    "vertical offset. y-coordinate of the upper-left corner of the upper-left pixel "
    translateY::Real

    AffineTransform(
        scaleX::Real,
        shearX::Real,
        translateX::Real,
        shearY::Real,
        scaleY::Real,
        translateY::Real,
    ) = new(scaleX, shearX, translateX, shearY, scaleY, translateY)

end

"""
Type used for defining a pixel grid on the surface of the Earth, via a map projection
See https://developers.google.com/earth-engine/reference/rest/v1beta/PixelGrid

$(TYPEDFIELDS)
"""
struct PixelGrid
    "dimensions of the pixel grid"
    dimensions::GridDimensions
    "affine transform of pixel grid"
    affineTransform::AffineTransform
    "standard coordinate reference system code (e.g. 'EPSG:4326')"
    crsCode::AbstractString

    PixelGrid(
        dimensions::GridDimensions,
        affinetransform::AffineTransform,
        crsCode::AbstractString,
    ) = new(dimensions, affinetransform, crsCode)
end

"""
    PixelGrid(bbox::AbstractVector, resolution::Real, crsCode::String)

PixelGrid constructor based on bounding box, resolution, and crs code
"""
function PixelGrid(bbox::AbstractVector, resolution::Real, crsCode::String)
    minx, miny, maxx, maxy = bbox
    y_coords = collect(range(miny + resolution, maxy, step = resolution))
    x_coords = collect(range(minx, maxx - resolution, step = resolution))
    xdim = length(x_coords)
    ydim = length(y_coords)

    dimensions = GridDimensions(xdim, ydim)

    affinetransform = AffineTransform(resolution, 0, minx, 0, -resolution, maxy)

    PixelGrid(dimensions, affinetransform, crsCode)
end

"""
    PixelGrid(bbox::AbstractVector, shape::AbstractVector{Integer}, crsCode::String)

PixelGrid constructor based on bounding box, image dimensions, and crs code
"""
function PixelGrid(
    bbox::AbstractVector{Real},
    shape::AbstractVector{Integer},
    crsCode::AbstractString,
)
    minx, miny, maxx, maxy = bbox
    xdim, ydim = shape
    xres = (maxx - minx) / xdim
    yres = (maxy - miny) / ydim

    griddims = GridDimension(xdim, ydim)

    transform = AffineTransform(xres, 0, minx, 0, -yres, maxy)

    PixelGrid(griddims, transform, crsCode)
end

"""
    PixelGrid(session::EESession,geom::EE.AbstractEEObject,resolution::Real,crsCode::String)

PixelGrid constructor based on an EarthEngine feature collection bounds, needs resolution and crs defined
"""
function PixelGrid(
    session::EESession,
    geom::EE.AbstractEEObject,
    resolution::Real,
    crsCode::String,
)
    coords = computevalue(session, coordinates(bounds(geom)))
    minx = min(coords[1, :, 1]...)
    maxx = max(coords[1, :, 1]...)
    miny = min(coords[1, :, 2]...)
    maxy = max(coords[1, :, 2]...)

    PixelGrid([minx, miny, maxx, maxy], resolution, crsCode)
end

struct CloudStorageDestination
    bucket::AbstractString
    filenamePrefix::AbstractString
    permissions::AbstractString
    bucketCorsUris::Vector{AbstractString}

    CloudStorageDestination(
        bucket::AbstractString,
        filenamePrefix::AbstractString,
        permissions::AbstractString,
        bucketCorsUris::Vector{AbstractString},
    ) = new(bucket, filenamePrefix, permissions, bucketCorsUris)
end

struct DoubleRange
    min::Real
    max::Real

    DoubleRange(min::Real, max::Real) = new(min, max)
end

struct DriveDestination
    folder::AbstractString
    filenamePrefix::AbstractString

    DriveDestination(folder::AbstractString, filenamePrefix::AbstractString) =
        new(folder, filenamePrefix)
end

struct EarthEngineDestination
    name::AbstractString

    EarthEngineDestination(name::AbstractString) = new(name)
end

struct Expression
    values::AbstractDict{Union{String,Symbol},Any}
    result::AbstractString

    Expression(
        values::AbstractDict{Union{AbstractString,Symbol},Any},
        result::AbstractString,
    ) = new(values, result)
end

struct Feature
    type::AbstractString
    geometry::AbstractDict{Union{AbstractString,Symbol},Any}
    properties::AbstractDict{Union{AbstractString,Symbol},Any}
end

struct VisualizationOptions
    ranges::AbstractVector{DoubleRange}
    paletteColors::AbstractVector{String}
    gamma::Real
    opacity::Real

    VisualizationOptions(
        ranges::AbstractVector{DoubleRange},
        paletteColors::AbstractVector{String},
        gamma::Real,
        opacity::Real,
    ) = new(ranges, paletteColors, gamma, opacity)

    function VisualizationOptions(
        range::DoubleRange,
        paletteColors::AbstractVector{String},
        gamma::Real,
        opacity::Real,
    )
        ranges = [range]
        new(ranges, paletteColors, gamma, opacity)
    end

end

struct ZoomSubset
    startof::Real
    endof::Real

    ZoomSubset(startof::Real, endof::Real) = new(startof, endof)
end

struct TileOptions
    startZoom::Integer
    skipEmpty::Bool
    mapsApiKey::String
    dimensions::GridDimensions
    stride::Integer
    zoomSubset::ZoomSubset
    endZoom::Integer
    scale::Real

    TileOptions(
        startZoom::Integer,
        skipEmpty::Bool,
        mapsApiKey::String,
        dimensions::GridDimensions,
        stride::Integer,
        zoomSubset::ZoomSubset,
        endZoom::Integer,
        scale::Real,
    ) = new(
        startZoom,
        skipEmpty,
        mapsApiKey,
        dimensions,
        stride,
        zoomSubset,
        endZoom,
        scale,
    )
end
