struct EESession
    project::AbstractString
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

struct GridDimensions
    width::Int
    height::Int

    GridDimensions(width::Int, height::Int) = new(width, height)
end

struct AffineTransform
    scaleX::Real
    shearX::Real
    translateX::Real
    shearY::Real
    scaleY::Real
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

struct PixelGrid
    dimensions::GridDimensions
    affineTransform::AffineTransform
    crsCode::AbstractString

    PixelGrid(
        dimensions::GridDimensions,
        affinetransform::AffineTransform,
        crsCode::AbstractString,
    ) = new(dimensions, affinetransform, crsCode)

    function PixelGrid(bbox::AbstractVector, resolution::Real, crsCode::String)
        minx, miny, maxx, maxy = bbox
        y_coords = collect(range(miny + resolution, maxy, step = resolution))
        x_coords = collect(range(minx, maxx - resolution, step = resolution))
        xdim = length(x_coords)
        ydim = length(y_coords)

        dimensions = GridDimensions(xdim, ydim)

        affinetransform =
            AffineTransform(resolution, 0, minx, 0, -resolution, maxy)

        new(dimensions, affinetransform, crsCode)
    end

    function PixelGrid(
        bbox::AbstractVector{Real},
        shape::AbstractVector{Int},
        crsCode::AbstractString,
    )
        minx, miny, maxx, maxy = bbox
        xdim, ydim = shape
        xres = (maxx - minx) / xdim
        yres = (maxy - miny) / ydim

        griddims = GridDimension(xdim, ydim)

        transform = AffineTransform(xres, 0, minx, 0, -yres, maxy)

        new(griddims, transform, crsCode)
    end

    function PixelGrid(
        start::AbstractVector{Real},
        stop::AbstractVector{Real},
        resolution::Real,
        crsCode::AbstractString,
    )

    end

    function PixelGrid(session::EESession,geom::EE.AbstractEEObject,resolution::Real,crsCode::String)
        coords = computevalue(session,coordinates(bounds(geom)))
        minx = min(coords[1,:,1]...)
        maxx = max(coords[1,:,1]...)
        miny = min(coords[1,:,2]...)
        maxy = max(coords[1,:,2]...)

        PixelGrid([minx,miny,maxx,maxy], resolution, crsCode)
    end
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

    DoubleRange(min::Real,max::Real) = new(min,max)
end

struct DriveDestination
    folder::AbstractString
    filenamePrefix::AbstractString

    DriveDestination(folder::AbstractString,filenamePrefix::AbstractString) = new(folder,filenamePrefix)
end

struct EarthEngineDestination
    name::AbstractString

    EarthEngineDestination(name::AbstractString) = new(name)
end

struct Expression
    values::AbstractDict{Union{String, Symbol},Any}
    result::AbstractString

    Expression(values::AbstractDict{Union{AbstractString, Symbol},Any},result::AbstractString) = new(values,result)
end

struct Feature
    type::AbstractString
    geometry::AbstractDict{Union{AbstractString, Symbol},Any}
    properties::AbstractDict{Union{AbstractString, Symbol},Any}
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
        ranges = [range,]
        new(ranges, paletteColors, gamma, opacity)
    end

end

struct ZoomSubset
    startof::Real
    endof::Real

    ZoomSubset(startof::Real, endof::Real) = new(startof, endof)
end

struct TileOptions
    startZoom::Int
    skipEmpty::Bool
    mapsApiKey::String
    dimensions::GridDimensions
    stride::Int
    zoomSubset::ZoomSubset
    endZoom::Int
    scale::Real

    TileOptions(
        startZoom::Int,
        skipEmpty::Bool,
        mapsApiKey::String,
        dimensions::GridDimensions,
        stride::Int,
        zoomSubset::ZoomSubset,
        endZoom::Int,
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
