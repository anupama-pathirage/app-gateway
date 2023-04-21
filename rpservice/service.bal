import ballerina/http;
//import rpservice.filters;
import ballerina/log;
import rpservice.interceptor;
import ballerina/jballerina.java;

// Define the endpoint URLs as a map (we may need to read this from a config file)
map<string> endpointUrls = {
    "/admin/sniff.jsp": "https://run.mocky.io/v3/6613f69c-65cf-44d4-b29c-7887f21cfd59",
    "/api/npx-service": "https://run.mocky.io/v3/84643c67-6ddb-4cf1-8141-f637154c9520",
    "/pmg/nxn-metrics": "https://run.mocky.io/v3/b6a301fc-64d8-497d-9138-058d8946bd70",
    "/app/nxn-resource-cache": "https://run.mocky.io/v3/34a9aeba-0b71-4fac-8451-b122c50cce45",
    "/api/nxn-navbar-service": "https://run.mocky.io/v3/8f5cd8a1-85ae-4d73-946b-59dda7ce5992"
};

// Engage interceptors at the service level. Request interceptor services will be executed from
// head to tail.
@http:ServiceConfig {
    // The interceptor pipeline. The base path of the interceptor services is the same as
    // the target service. Hence, they will be executed only for this particular service.
    //interceptors: [new filters:RequestInterceptor()]
}
service / on new http:Listener(9095) {

    resource function 'default [string... paths](http:Caller caller, http:Request req) returns error? {
        //TODO dynamically invoke the BE based on plugin chain context and return
        //return string `method: ${req.method}, path: ${paths.toString()}`;
        //string path = req.rawPath;
        string urlPostfix = req.rawPath; //replaceFirst(req.rawPath,paths[0],"");

        if (urlPostfix != "" && !hasPrefix(urlPostfix, "/")) {
            urlPostfix = "/" + urlPostfix;
        }

        if(endpointUrls[req.rawPath] == ()) {
            http:Response response = new ();
                response.setJsonPayload("{error: \"resouce not available\"}");
                response.statusCode = 404;
                http:ListenerError? respond = caller->respond(response);
                if respond is http:ListenerError {

                }
                if respond is error {

                }
            log:printError("No endpoint found for path: ", a = req.rawPath);
            return;
        }

        //request interceptor pre-processing
        boolean pluginres = check interceptor:interceptRequest(caller, req);
        if !pluginres {
            return;
        }
        //TODO validate request chain context and return

        
        var result = callEndpoint(caller, req, <string>endpointUrls[req.rawPath], urlPostfix);

        // response interceptor post-processing
        boolean respresult = interceptor:interceptResponse(caller, req);
         if !respresult {
            return;
        }

        if (result is error) {
            log:printError("Error calling endpoint: ", err = result.toString());
        }

        return result;
    }
}

// Define the function that calls an endpoint
function callEndpoint(http:Caller caller, http:Request request, string endpointUrl, string urlPostfix) returns error? {
    http:Client httpClient = check new (endpointUrl);
    log:printInfo("HTTP call: ", a = endpointUrl, b = urlPostfix);
    http:Response|http:ClientError response = httpClient->forward(urlPostfix, request);
    if (response is http:Response) {
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error sending response: ", err = result.toString());
        }
        return result;
    } else {
        //log:printError("Error calling endpoint: ", err );
    }
}

public function replaceFirst(string str, string regex, string replacement) returns string {
    handle reg = java:fromString(regex);
    handle rep = java:fromString(replacement);
    handle rec = java:fromString(str);
    handle newStr = jReplaceFirst(rec, reg, rep);

    return newStr.toString();
}

public function hasPrefix(string str, string prefix) returns boolean {
    handle pref = java:fromString(prefix);
    handle rec = java:fromString(str);

    return jStartsWith(rec, pref);
}

function jStartsWith(handle receiver, handle prefix) returns boolean = @java:Method {
    name: "startsWith",
    'class: "java.lang.String",
    paramTypes: ["java.lang.String"]
} external;

function jReplaceFirst(handle receiver, handle regex, handle replacement) returns handle = @java:Method {
    name: "replaceFirst",
    'class: "java.lang.String"
} external;

//http:Response res = new;
//res.setPayload(string `method: ${req.method}, path: ${paths.toString()}`);
//return res;