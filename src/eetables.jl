# script for sending request for table computation

"""
    computetable(session::EESession, featurecollection::EE.AbstractEEObject)

Fuction to request data from EarthEngine FeatureCollection and return as a GeoDataFrame.
See https://developers.google.com/earth-engine/reference/rest/v1beta/projects.table/computeFeatures
"""
function computetable(
    session::EESession,
    featurecollection::EE.AbstractEEObject,
)

    endpoint = "table:computeFeatures"

    serialized = ee.serializer.encode(featurecollection, for_cloud_api = true)

    payload = Dict(:expression => serialized)

    response = _sendrequest(session, endpoint, payload)

    return GeoDataFrames.read(response.content)
end
