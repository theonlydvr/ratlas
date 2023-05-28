function nodes = loadSVG(file)
    global nodes I
    xDoc = xmlread(file);
    children = parseChildNodes(xDoc);
    count = 0;
    for i=1:length(children)
        count = count + countNodes(children(i));
    end
    nodes = Path.empty(count, 0);
    I = 1;
    for i=1:length(children)
        parseSVGNode(children(i), struct());
    end
end

function count = countNodes(theNode)
    if ~isempty(theNode.Children)
        childNodes = theNode.Children;
        numChildNodes = length(childNodes);
        count = 0;
        for i = 1:numChildNodes
            count = count + countNodes(childNodes(i));
        end
    else
        if strcmp(theNode.Name, 'path')
            count = 1;
        else
            count = 0;
        end
    end
end

function parseSVGNode(theNode, parent)
    global nodes I
    if ~isempty(theNode.Children)
        childNodes = theNode.Children;
        numChildNodes = length(childNodes);
        for count = 1:numChildNodes
            parseSVGNode(childNodes(count), theNode);
        end
    end
    if strcmp(theNode.Name, 'path')
        nodes(I) = Path(theNode, parent);
        I = I + 1;
    end
end

function children = parseChildNodes(theNode)
    children = [];
    if theNode.hasChildNodes
       childNodes = theNode.getChildNodes;
       numChildNodes = childNodes.getLength;
       allocCell = cell(1, numChildNodes);

       children = struct(             ...
          'Name', allocCell, 'Attributes', allocCell,    ...
          'Data', allocCell, 'Children', allocCell);
    
        for count = 1:numChildNodes
            theChild = childNodes.item(count-1);
            children(count) = makeStructFromNode(theChild);
        end
    end
end

function nodeStruct = makeStructFromNode(theNode)
    % Create structure of node info.
    nodeStruct = struct(                        ...
       'Name', char(theNode.getNodeName),       ...
       'Attributes', parseAttributes(theNode),  ...
       'Data', '',                              ...
       'Children', parseChildNodes(theNode));
    
    if any(strcmp(methods(theNode), 'getData'))
       nodeStruct.Data = char(theNode.getData); 
    else
       nodeStruct.Data = '';
    end
end

function attributes = parseAttributes(theNode)
    % Create attributes structure.
    attributes = [];
    if theNode.hasAttributes
       theAttributes = theNode.getAttributes;
       numAttributes = theAttributes.getLength;
       allocCell = cell(1, numAttributes);
       attributes = struct('Name', allocCell, 'Value', ...
                           allocCell);
    
       for count = 1:numAttributes
          attrib = theAttributes.item(count-1);
          attributes(count).Name = char(attrib.getName);
          attributes(count).Value = char(attrib.getValue);
       end
    end
end