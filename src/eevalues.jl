# script for arbitrary computation of EE value

function computevalue(session::EESession, value::EE.AbstractEEObject)
    endpoint = "value:compute"

    serialized = ee.serializer.encode(value, for_cloud_api = true)

    payload = Dict(:expression => serialized)

    response = _sendrequest(session, endpoint, payload)

    return response.json()["result"]
end
