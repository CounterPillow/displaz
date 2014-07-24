#version 130


uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 modelViewProjectionMatrix;

//------------------------------------------------------------------------------
#if defined(VERTEX_SHADER)

uniform float pointRadius = 1.4;     //# uiname=Point Radius (m); min=0.001; max=10
uniform float trimRadius = 1000000;//# uiname=Trim Radius; min=1; max=1000000
uniform float exposure = 1.0;      //# uiname=Exposure; min=0.01; max=10000
uniform float contrast = 1.0;      //# uiname=Contrast; min=0.01; max=10000
const int colorMode = 0;         //# uiname=Colour Mode; enum=Intensity|Colour|Return Number|Number Of Returns|Point Source|Classification|File Number
uniform int markerShape = 0;
uniform float minPointSize = 0;
uniform float maxPointSize = 400.0;
// Point size multiplier to get from a width in projected coordinates to the
// number of pixels across as required for gl_PointSize
uniform float pointPixelScale = 0;

uniform float lodMultiplier = 1;
in float coverage;
uniform vec3 cursorPos = vec3(0);
uniform int fileNumber = 0;
in float intensity;
in float simplifyThreshold;
in vec3 position;
//in vec3 color;

flat out float modifiedPointRadius;
flat out float pointScreenSize;
flat out vec3 pointColor;
flat out int fragMarkerShape;

float tonemap(float x, float exposure, float contrast)
{
    float Y = exposure*pow(x, contrast);
    Y = Y / (1.0 + Y);
    return Y;
}

void main()
{
    vec4 p = modelViewProjectionMatrix * vec4(position,1.0);
    float r = length(position.xy - cursorPos.xy);
    float trimFalloffLen = min(5, trimRadius/2);
    float trimScale = min(1, (trimRadius - r)/trimFalloffLen);
    modifiedPointRadius = pointRadius * trimScale * coverage * lodMultiplier;
    pointScreenSize = clamp(2*pointPixelScale*modifiedPointRadius / p.w, minPointSize, maxPointSize);
    fragMarkerShape = markerShape;
    // Compute vertex color
    if (colorMode == 0)
        pointColor = tonemap(intensity/400.0, exposure, contrast) * vec3(1);
    else if (colorMode == 1)
        pointColor = contrast*(exposure*color - vec3(0.5)) + vec3(0.5);
    // Ensure zero size points are discarded.  The actual minimum point size is
    // hardware and driver dependent, so set the fragMarkerShape to discarded for
    // good measure.
    if (pointScreenSize <= simplifyThreshold)
    {
        pointScreenSize = 0;
        fragMarkerShape = -1;
    }
    gl_PointSize = pointScreenSize;
    gl_Position = p;
}


//------------------------------------------------------------------------------
#elif defined(FRAGMENT_SHADER)

uniform float markerWidth = 0.3;

flat in float modifiedPointRadius;
flat in float pointScreenSize;
flat in vec3 pointColor;
flat in int fragMarkerShape;

out vec4 fragColor;

// Limit at which the point is rendered as a small square for antialiasing
// rather than using a specific marker shape
const float pointScreenSizeLimit = 2;
const float sqrt2 = 1.414213562;

void main()
{
    if (fragMarkerShape < 0) // fragMarkerShape == -1: discarded.
        discard;
    // (fragMarkerShape == 0: Square shape)
    gl_FragDepth = gl_FragCoord.z;
    if (fragMarkerShape > 0 && pointScreenSize > pointScreenSizeLimit)
    {
        vec2 p = 2*(gl_PointCoord - 0.5);
        float r = length(p);
        if (r > 1)
            discard;
        if (fragMarkerShape == 1) // shape: sphere
        {
            gl_FragDepth += projectionMatrix[3][2] * gl_FragCoord.w*gl_FragCoord.w
                            // TODO: Why is the factor of 0.5 required here?
                            * 0.5*modifiedPointRadius*sqrt(1-r*r);
        }
    }
    fragColor = vec4(pointColor, 1);
}

#endif

