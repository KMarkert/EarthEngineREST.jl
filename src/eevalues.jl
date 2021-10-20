# script for arbitrary computation of EE value

"""
    computevalue(session::EESession, value::EE.AbstractEEObject)

Fuction to request data from any arbitrary EarthEngine computation and return as
the appropriate Julia object.
See https://developers.google.com/earth-engine/reference/rest/v1beta/projects.value/compute
"""
function computevalue(session::EESession, value::EE.AbstractEEObject)
    endpoint = "value:compute"

    serialized = ee.serializer.encode(value, for_cloud_api = true)

    payload = Dict(:expression => serialized)

    response = _sendrequest(session, endpoint, payload)

    return response.json()["result"]
end
