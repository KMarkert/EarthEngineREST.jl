# script for sending request for table computation

function computetable(
    session::EESession,
    featurecollection::EE.AbstractEEObject,
)
    """Base fuction to request ee.Feature or ee.FeatureCollection
    args:
        session (EESession): restee session autheticated to make requests
        featurecollection (ee.FeatureCollection): ee.FeatureCollections to request data from
    returns:
        bytes: raw byte data of table in geojson format requested
    """

    endpoint = "table:computeFeatures"

    serialized = ee.serializer.encode(featurecollection, for_cloud_api = true)

    payload = Dict("expression" => serialized)

    response = _sendrequest(session, endpoint, payload)

    return GeoDataFrames.read(response.content)
end
