__precompile__()

module EarthEngineREST

using NPZ
using Retry
using JSON3
using PyCall
using GeoArrays
using EarthEngine
using GeoDataFrames
using DocStringExtensions
import EarthEngine: Initialize
import GeoArrays: geotransform_to_affine


# define a constant pointer to the ee object
const serviceaccount = PyNULL()
const gauth = PyNULL()

# specify different urls and routings based on api version
const baseurl = "https://earthengine.googleapis.com"
const alphaapi = joinpath(baseurl, "v1alpha")
const betaapi = joinpath(baseurl, "v1beta")
const latestapi = betaapi

# create a lookup dictionary of api paths so users can use their preference
# add more as different versions become available
const apis = Dict("alpha" => alphaapi, "beta" => betaapi, "latest" => latestapi)

include("eeresttypes.jl")
include("eevalues.jl")
include("eeimages.jl")
include("eetables.jl")


"""
    _sendrequest(session::EESession, endpoint::AbstractString, data::Dict{Symbol,<:Any}; version::AbstractString = "latest", nretries::Integer = 4)

Private function for sending requests to EarthEngine REST API. Uses exponential backoff to retry requests if failed with non-fatal error.
"""
function _sendrequest(
    session::EESession,
    endpoint::AbstractString,
    data::Dict{Symbol,<:Any};
    version::AbstractString = "latest",
    nretries::Integer = 4
)
    url = joinpath(apis[version], "projects", session.project, endpoint)

    @repeat nretries try
        response = session.auth.post(url = url, data = JSON3.write(data))

    catch e
        @delay_retry if e.status_code < 200 && e.status_code >= 500
        end
    end
end

"""
    typetodict(x::T)

Function to convert EarthEngineREST types to dictionary key,value pairs to encode
for API requests
"""
function typetodict(x::T)::Dict{Symbol,Any} where {T}
    fields = fieldnames(T)
    outdict = Dict{Symbol,Any}()
    for fn in fields
        subfield = getfield(x, fn)
        fn = String(fn)
        if length(fieldnames(typeof(subfield))) > 0
            if endswith(String(fn), "of")
                fn = replace(fn, "of" => "")
            end

            outdict[Symbol(fn)] = typetodict(subfield)
        else
            if endswith(fn, "of")
                fn = replace(fn, "of" => "")
            end

            outdict[Symbol(fn)] = subfield
        end
    end
    return outdict
end

"""
    extract_geotransform(x::AffineTransform)

Function to extract geotransform vector from AffineTransformation type
"""
function extract_geotransform(x::AffineTransform)
    af = typetodict(x)
    gt = [
        af[:translateX],
        af[:scaleX],
        af[:shearX],
        af[:translateY],
        af[:shearY],
        af[:scaleY],
    ]
end

"""
    extract_geotransform(x::PixelGrid)

Function to extract geotransform vector from PixelGrid type
"""
function extract_geotransform(x::PixelGrid)
    extract_geotransform(x.affineTransform)
end

"""
    extract_bbox(x::AffineTransform, griddims::GridDimensions)

Function to extract bounding box vector from AffineTransform type. Vector will be [W, S, E, N]
"""
function extract_bbox(x::AffineTransform, griddims::GridDimensions)
    geo_t = extract_geotransform(x)
    x_size = griddims.width
    y_size = griddims.height

    xmin = min(geo_t[1], geo_t[1] + x_size * geo_t[2])
    xmax = max(geo_t[1], geo_t[1] + x_size * geo_t[2])
    ymin = min(geo_t[4], geo_t[4] + y_size * geo_t[6])
    ymax = max(geo_t[4], geo_t[4] + y_size * geo_t[6])

    return [xmin, ymin, xmax, ymax]
end

"""
    extract_bbox(x::PixelGrid)

Function to extract bounding box vector from PixelGrid type. Vector will be [W, S, E, N]
"""
function extract_bbox(x::PixelGrid)
    extract_bbox(x.affineTransform,x.dimensions)
end

"""
    extract_affinemap(x::AffineTransform)

Function to extract AffineMap type from AffineTransform type.
"""
function extract_affinemap(x::AffineTransform)
    gt = extract_geotransform(x)
    return geotransform_to_affine(gt)
end

"""
    extract_affinemap(x::PixelGrid)

Function to extract AffineMap type from PixelGrid type.
"""
function extract_affinemap(x::PixelGrid)
    extract_affinemap(x.affineTransform)
end

function extract_lonslats(x::AffineTransform)
    gt = extract_geotransform()

end

"""
    extract_gridcoordinates(x::PixelGrid)

Function to convert PixelGrid to vectors of lat lon coordinates. Returns
a tuple of (lon::Vector{Float64}, lat::Vector{Float64}).
"""
function extract_gridcoordinates(x::PixelGrid)
    bbox = extract_bbox(x)
    gt = extract_geotransform(x)

    lons = collect(bbox[1]:abs(gt[2]):bbox[3])[1:end-1]
    lats = collect(bbox[2]:abs(gt[6]):bbox[4])[2:end]

    return lons, lats
end

"""
    Initialize(session::EESession)

Extends the `Initialize()` function to take an authenticated Earth Engine session
and use those credentials.
"""
function Initialize(session::EESession)
    EarthEngine.Initialize(session.auth.credentials)
end

export Initialize, EESession, PixelGrid, GridDimensions, AffineTransform, computepixels, computetable, computevalue

end # module
