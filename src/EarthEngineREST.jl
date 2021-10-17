__precompile__()

module EarthEngineREST

using NPZ
using Retry
using JSON3
using PyCall
using GeoArrays
using EarthEngine
using GeoDataFrames
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

function _sendrequest(
    session::EESession,
    endpoint::AbstractString,
    data::Dict{Symbol,<:Any};
    version::AbstractString = "latest",
)
    url = joinpath(apis[version], "projects", session.project, endpoint)

    @repeat 4 try
        response = session.auth.post(url = url, data = JSON3.write(data))

    catch e
        @delay_retry if e.status_code < 200 && e.status_code >= 500
        end
    end
end

"""
    typetodict(x::T)


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
    extract_geotransform(x::PixelGrid)


"""
function extract_geotransform(x::PixelGrid)
    af = typetodict(x.affineTransform)
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
    extract_bbox(x::PixelGrid)


"""
function extract_bbox(x::PixelGrid)
    geo_t = extract_geotransform(x)

    xmin = min(geo_t[1], geo_t[1] + x_size * geo_t[2])
    xmax = max(geo_t[1], geo_t[1] + x_size * geo_t[2])
    ymin = min(geo_t[4], geo_t[4] + y_size * geo_t[6])
    ymax = max(geo_t[4], geo_t[4] + y_size * geo_t[6])

    return [xmin, ymin, xmax, ymax]
end

"""
    extract_affinemap(x::PixelGrid)


"""
function extract_affinemap(x::PixelGrid)
    gt = extract_geotransform(x)
    return geotransform_to_affine(gt)
end

function Initialize(session::EESession)
    EarthEngine.Initialize(session.auth.credentials)
end

export Initialize, EESession, PixelGrid, GridDimensions, AffineTransform

end # module
