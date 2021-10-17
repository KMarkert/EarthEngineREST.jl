# script for sending and decoding requests for image computations

function parseheader(hdr::AbstractString)
    s = NPZ.parsechar(hdr, '{')

    dict = Dict{String,Any}()
    T = Any
    for _ = 1:3
        s = strip(s)
        key, s = NPZ.parsestring(s)
        s = strip(s)
        s = NPZ.parsechar(s, ':')
        s = strip(s)
        if key == "descr"
            x, s = split(s, ", 'for")
            y = split(
                replace(
                    replace(
                        replace(
                            replace(replace(x, "[" => ""), "]" => ""),
                            "(" => "",
                        ),
                        ")" => "",
                    ),
                    "'" => "",
                ),
                ",",
            )

            bnames = []
            dtypes = []
            for z in y
                if occursin("<", z)
                    push!(dtypes, replace(strip(z), "<" => ""))
                elseif occursin(">", z)
                    push!(dtypes, replace(strip(z), ">" => ""))
                else
                    push!(bnames, strip(z))
                end
            end

            dict[key] = Dict(bnames .=> dtypes)

            # kinda hacky way of reconstructing the header info after splitting...
            s = ", 'for$(s)"

        elseif key == "fortran_order"
            dict[key], s = NPZ.parsebool(s)
        elseif key == "shape"
            dict[key], s = NPZ.parsetuple(s)
        else
            error("parsing header failed: bad dictionary key")
        end
        s = strip(s)
        if s[firstindex(s)] == '}'
            break
        end
        s = NPZ.parsechar(s, ',')
    end
    return dict
end


function decoderesponse(response::PyObject)
    foo = response.content

    hdr = parseheader(strip(split(foo, "\n")[1])[11:end])

    banddtypes = map(x -> NPZ.Numpy2Julia[x], values(hdr["descr"]))

    sametyped = all(x -> x == banddtypes[1], banddtypes)

    if ~sametyped
        @error(
            "Resulting bands have different data types, creating arrays with different band dtypes is currently not support ...Try explicitly casting the image to the same data type (ie `ee.Image().toFloat()`)."
        )
    end

    dtype = banddtypes[1]

    buffer = IOBuffer()
    write(buffer, foo)
    bar = reinterpret(dtype, take!(buffer))
    close(buffer) # close the io buffer for clean memory management

    # get the data shape of the bytes
    height, width = hdr["shape"]
    channels = length(banddtypes)

    # find the number of pixels we expect based on img
    data_size::Int64 = width * height * channels
    # find the offset of what was returned vs what is expected
    offset::Int64 = size(bar, 1) - data_size + 1

    arr::Array{dtype,1} = dtype.(bar)[offset:end]

    if channels > 1
        # reshape array from 1-d to correct 3-d dimensions
        arr3d::Array{dtype,3} = reshape(arr, (channels, width, height))
        # reorder the dimensions for row-major to column-major
        img = permutedims(arr3d, (2, 3, 1))
    else
        arr2d::Array{dtype,2} = reshape(arr, (width, height))
        img = arr2d #rotl90(arr2d)
    end

    # cast the result as a float32 array
    # img = convert(Array{Float32}, img)
    return img
end

function computepixels(
    session::EESession,
    pixelgrid::PixelGrid,
    image::EE.AbstractEEObject;
    format::AbstractString = "NPY",
)
    bands = computevalue(session, bandNames(image))

    computepixels(session, pixelgrid, image, bands; format = format)

end

function computepixels(
    session::EESession,
    pixelgrid::PixelGrid,
    image::EE.AbstractEEObject,
    bands::AbstractVector;
    format::AbstractString = "NPY",
)
    endpoint = "image:computePixels"

    serialized = ee.serializer.encode(image, for_cloud_api = true)

    payload = Dict(
        :expression => serialized,
        :grid => typetodict(pixelgrid),
        :fileFormat => format,
        :bandIds => bands,
    )

    response = _sendrequest(session, endpoint, payload)

    result = decoderesponse(response)

    affine = extract_affinemap(pixelgrid)

    output = GeoArray(result, affine, pixelgrid.crsCode)

    return output
end
