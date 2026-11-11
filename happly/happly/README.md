<p align="center">
<img src="https://github.com/nmwsharp/happly/blob/master/happly_logo.jpg" width="200"> 
</p>
<p align="center">A header-only C++ reader/writer for the PLY file format. Parse .ply happily! <p align="center">

### Fork log by MarcusTU

[Initial copy of nmwsharp/happly]

[Changes from 07.05.2025 by MarcusTU]

[Added]<br>
`bool Element::hasListPropertyType`<br>
`(const std::string& target)`<br>
[Reason]<br>
There was no analogon to hasPropertyType for list properties<br>

[Added]<br>
`std::string PLYData::getPropertyTypeName`<br>
`(const std::string & propertyName)`<br>
[Reason]<br>
There was no possibility to get the property type name from the outside<br>

[Added]<br>
`bool Element::isListProperty`<br>
`(const std::string & propertyName)`<br>
[Reason]<br>
There was no possibility to check if a property is a list property from the outside<br>

[Added]<br>
`std::vector<std::array<PositionT, 3>> PLYData::getVertexNormals`<br>
`(const std::string& vertexElementName = "vertex")`<br>
[Reason]<br>
There is a wrapper for positions (getVertexPositions) but the one for normals was missing<br>

[Added]<br>
`void PLYData::addElementNormals`<br>
`(std::string const& elementName, std::vector<std::array<PositionT, 3>>& elementNormals)`<br>
[Reason]<br>
There is a wrapper for positions (addVertexPositions) but the one for normals was missing<br>

[Added]<br>
`void PLYData::addElementProperty`<br>
`(std::vector<T> const & data, std::string const & elementName, std::string const & propertyName)`<br>
[Reason]<br>
There was no wrapper for adding data to element properties in a smooth way<br>

[Added]<br>
`void PLYData::addElementListProperty`<br>
`(std::vector<std::vector<T>> const & data, std::string const & elementName, std::string const & listPropertyName)`<br>
[Reason]<br>
There was no wrapper for adding data to element list properties in a smooth way<br>

[Changed]<br>
`void PLYData::addElementColors`<br>
`(std::string const& elementName, std::vector<std::array<double, 3>>& colors)`<br>
[InsteadOf]<br>
`void PLYData::addVertexColors`<br>
`(std::vector<std::array<double, 3>>& colors)`<br>
[Reason]<br>
More general version of the same function that can set colors to any element and not only to vertices<br>

[Changed]<br>
`void PLYData::addElementColors`<br>
`(std::string const& elementName, std::vector<std::array<unsigned char, 3>>& colors)`<br>
[InsteadOf]<br>
`void PLYData::addVertexColors`<br>
`(std::vector<std::array<unsigned char, 3>>& colors)`<br>
[Reason]<br>
More general version of the same function that can set colors to any element and not only to vertices<br>

[Changed]<br>
`void PLYData::addVertexPositions`<br>
`(std::vector<std::array<PositionT, 3>>& vertexPositions)`<br>
[InsteadOf]<br>
`void PLYData::addVertexPositions`<br>
`(std::vector<std::array<double, 3>>& vertexPositions)`<br>
[Reason]<br>
This allows for float and double positions instead of only double ones<br>

[Fixed C4702]<br>
`S* addressIfSame`<br>
`(T&, char)`<br>

[Added]<br>
`template<typename T> bool PLYData::hasElementPropertyType`<br>
`(const std::string & elementName, const std::string & propertyName)`<br>
[Reason]<br>
There was no smooth way to check if an element with property of type T exists<br>

[Added]<br>
`template<typename T> bool PLYData::hasElementListPropertyType`<br>
`(const std::string & elementName, const std::string & listPropertyName)`<br>
[Reason]<br>
There was no smooth way to check if an element with list property of type T exists<br>

[Added]<br>
`bool PLYData::hasDoublePrecisionVertices`<br>
`()`<br>
[Reason]<br>
Allows for a check if the vertices are stored with double precision<br>

[Added]<br>
`bool PLYData::hasDoublePrecisionNormals`<br>
`()`<br>
[Reason]<br>
Allows for a check if the normals are stored with double precision<br>
