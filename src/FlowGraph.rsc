module FlowGraph

import analysis::flow::ObjectFlow;
import lang::java::flow::JavaToObjectFlow;
import List;
import Relation;
import lang::java::m3::Core;
import analysis::m3::Core;
import lang::java::jdt::m3::AST;
import lang::java::jdt::m3::Core;

import IO;
import vis::Figure; 
import vis::Render;

import Set;
import String;

alias OFG = rel[loc from, loc to];

data Arity = inf() | fixed(int size);

OFG buildGraph(FlowProgram p) 
  = {}
  	// x = new c(as1, as2, ...)
  	// constructor def c(fps1, fps2, ...)
	  	// link values (as) to parameters (fps)
	  	//*
	  	+ { <as[i], fps[i]> | 
	        newAssign(x, _, c, as) <- p.statements, 
	        constructor(c, fps) <- p.decls,
	        i <- index(as) 
	    }
	    //*/
	    // link c.this to x
	    //*
	    + { <c + "this", x> |
	        newAssign(x, _, c, as) <- p.statements
	    }
	    //*/
	
	// x = y
		// link y to x
		//*
		+ { <y, x> |
			assign(x, _, y) <- p.statements
		}
		//*/
		
	// x = y.m(as1, as2, ...)
	// method def m(fps1, fps2, ...)
		// link values (as) to parameters (fps)
	    //*
	    + { <as[i], fps[i]> | 
	        call(x, _, y, m, as) <- p.statements, 
	        method(m, fps) <- p.decls,
	        i <- index(as) 
	    }
  		//*/
  		// link m.return to x
  		//* !! possible problem: for a statement "y.m(as1, as2, ...)", we have |id:///| as value for x, should this case be ignored?
  		+ { <m + "return", x> |
        	call(x, _, y, m, as) <- p.statements,
        	method(m, fps) <- p.decls
        }
  		//*/
  		// link y to m.this
  		//*
  		+ { <y, m + "this"> |
        	call(x, _, y, m, as) <- p.statements,
        	method(m, fps) <- p.decls
        }
        //*/
  ;

rel[loc, loc] buildForwardGen(FlowProgram p)
	= { <cs + "this", cl> |
		newAssign(_, cl, cs, _) <- p.statements
	  };
	
rel[loc, loc] buildBackwardGen(FlowProgram p)
    = { <s, c> |
        assign(t, c, s) <- p.statements,
        c.path != "/"
      }
    + { <m + "return", c> |
        call(_, c, _, m, _) <- p.statements,
        c.path != "/"
      };

OFG prop(OFG g, rel[loc,loc] gen, rel[loc,loc] kill, bool back) {
  OFG IN = { };
  OFG OUT = gen + (IN - kill);
  gi = g<to,from>; // gi inverted relation of g
  set[loc] pred(loc n) = gi[n];
  set[loc] succ(loc n) = g[n];
  
  solve (IN, OUT) {
    IN = { <n,\o> |
    	n <- carrier(g),
    	p <- (back ? pred(n) : succ(n)),
    	\o <- OUT[p]
    };
    OUT = gen + (IN - kill);
  }
  return OUT;
}



public str dotOFGDiagram(OFG g, OFG g2) {
  rel[loc, loc] filterG = { <from, to> | <from, to> <- g, !isEmpty(g2[to]), to.path != "/" };
  set[loc] elems = carrier(filterG);
  
  str getLabel(l) {
    list[loc] s = toList(g2[l]);
    str ret = "<for (e <- s) {><e.file>, \\l<}>";
    return ret[..-4];
  }
  
  return "digraph classes {
         '  ratio=\"fill\"
         '  graph []
         '  fontname = \"Bitstream Vera Sans\"
         '  fontsize = 8
         '  node [ fontname = \"Bitstream Vera Sans\" fontsize = 8 shape = \"record\" ]
         '  edge [ fontname = \"Bitstream Vera Sans\" fontsize = 8 ]
         '
         '  <for (cl <- elems) {>
         '  \"N<cl>\" [label = \"{<cl.path>}\"]
         '  <}>
         '  <for (<from, to> <- filterG) {>
         '  \"N<from>\" -\> \"N<to>\" [label=\"{<getLabel(to)>}\\l\", arrowhead=\"vee\"]<}>
         '}";
}

public str dotDiagram(OFG g, FlowProgram p, M3 m, bool \filter) {

  set[loc] allTypes = classes(m) + interfaces(m);
  
  rel[loc, loc] extends = { <from, to> |
                            <from, to> <- m@extends,
                            from <- allTypes,
                            to <- allTypes};
                            
  rel[loc, loc] implements = { <from, to> |
                               <from, to> <- m@implements,
                               from <- allTypes,
                               to <- allTypes};

  rel[loc, loc, loc] individualAssociations = {
    <field, class1, class2> |
    <class1, field> <- m@containment,
    <field, class2> <- g,
    field <- fields(m),
    class1 <- allTypes,
    class2 <- allTypes
  };
  
  rel[loc, loc] associations = {
    <class1, class2> |
    <_, class1, class2> <- individualAssociations
  };
  
  str multiplicity(tuple[loc to, loc from] edge) {
    tuple[Arity min, Arity max] m = calcMultiplicity(invert(individualAssociations)[edge.to][edge.from]);
    return "<arityToString(m.min)>..<arityToString(m.max)>";
  }
  
  str arityToString(inf()) = "*";
  str arityToString(fixed(int a)) = "<a>";
  
  set[str] containerClasses =  {
     "/java/util/Map"
    ,"/java/util/HashMap"
    ,"/java/util/Collection"
    ,"/java/util/Set"
    ,"/java/util/HashSet"
    ,"/java/util/LinkedHashSet"
    ,"/java/util/List"
    ,"/java/util/ArrayList"
    ,"/java/util/LinkedList"
  };
  
  tuple[Arity, Arity] calcMultiplicity(set[loc] fields) {
    Arity min = fixed(0);
    Arity max = fixed(0);
    for (loc field <- fields) {
        loc \type = toList(m@typeDependency[field])[0];
        if (\type.path in containerClasses) {
            max = inf();
        } else {
            max = arityPlus(max, fixed(1));
        }
    }
    return <min, max>;
  }
  
  Arity arityPlus(fixed(int a), fixed(int b)) = fixed(a + b);
  Arity arityPlus(inf(), fixed(int b)) = inf();
  Arity arityPlus(fixed(int a), inf) = inf;
  
  rel[loc, loc] identity = { <class, class> | class <- carrier(g) };
  
  rel[loc, loc, loc] individualDependencies = {
    <var, class1, class2> |
    <method, var> <- m@containment,
    <class1, method> <- m@containment,
    <var, class2> <- g,
    var <- variables(m) + parameters(m),
    class1 <- allTypes,
    class2 <- allTypes
  };
  
  rel[loc, loc] dependencies = {
    <class1, class2> |
    <_, class1, class2> <- individualDependencies
  } - associations - m@extends<to, from> - identity;
  
  rel[loc, loc] filterRelation(rel[loc,loc] relation, rel[loc,loc] subtypes) {
    rel[loc, loc] simplifications = {};
    rel[loc, loc] filteredRelation = relation;
    rel[loc, loc] subtypesI = invert(subtypes);
    
    solve (simplifications, filteredRelation) {
      simplifications = { <from, super> |
          from <- domain(relation),
          super <- range(subtypes),
          (subtypesI[super] <= relation[from])
      };
      filteredRelation = filteredRelation - 
                         { <from, to> | 
                           <to, super> <- subtypes,
                           <from, super> <- simplifications} +
                         simplifications;
    }
    return filteredRelation;
  }
  
  rel[loc, loc] filteredAssociations = filterRelation(associations, extends + implements);
  
  rel[loc, loc] filteredDependencies = filterRelation(dependencies, extends + implements) - 
                                       filteredAssociations - invert(extends) - identity;
    
  str classString(loc cl, bool interface) {
    return "\"N<cl>\" [
    '  label = \<\<TABLE BORDER=\"0\" ALIGN=\"LEFT\" CELLBORDER=\"1\" CELLSPACING=\"0\" CELLPADDING=\"4\"\>
    '    \<TR\>\<TD\><if(interface){>«interface»\<BR /\><}><if(\abstract() in m@modifiers[cl]){>\<i\><}><cl.path[1..]><if(\abstract() in m@modifiers[cl]){>\</i\><}>\</TD\>\</TR\>
    '    \<TR\>\<TD ALIGN=\"LEFT\" BALIGN=\"LEFT\"\><for (<cl, field> <- m@containment, <field, \type> <- m@typeDependency, field <- fields(m)) {><fieldString(cl, field, \type)>\<BR /\><}>\</TD\>\</TR\>
    '    \<TR\>\<TD ALIGN=\"LEFT\" BALIGN=\"LEFT\"\><for (<cl, const> <- m@containment, const <- constructors(m)) {><constString(cl, const)>\<BR /\><}><for (<cl, meth> <- m@containment, meth <- methods(m), meth.scheme == "java+method") {><methString(cl, meth)>\<br /\><}>\</TD\>\</TR\>
    '  \</TABLE\>\>
    ']";
  }
  
  str getVarType(loc class, loc var, loc \type) {
    if (\type.path in containerClasses) {
        rel[loc, loc, loc] individualRel = {};
        rel[loc, loc] \rel = {};
        if (var.scheme == "java+field") {
            individualRel = individualAssociations;
            if (\filter) {
                \rel = filteredAssociations;
            } else {
                \rel = associations;
            }
        } else {
            individualRel = individualDependencies;
            if (\filter) {
                \rel = filteredDependencies;
            } else {
                \rel = dependencies;
            }
        }
        set[loc] canContain = { to | <var, class, to> <- individualRel,
                                     <class, to> <- \rel};
        
        return "<\type.file>&lt;<typeListToString(canContain)>&gt;";
    } else {
        return "<\type.file>";
    }
  }
  
  str typeListToString(set[loc] \list) {
    str ret = "<for(\type <- \list) {><\type.file>|<}>";
    return ret[0..-1];
  }
  
  str getModifier(loc decl) {
    return if (\public() in m@modifiers[decl]) "+"; else 
           if (\private() in m@modifiers[decl]) "-"; else
           if (\protected() in m@modifiers[decl]) "#"; else "~";
  }
  
  str constString(loc class, loc const) {
    set[str] names = (m@names<qualifiedName, simpleName>)[const];
    str name = "";
    if (isEmpty(names)) {
        name = "<const>";
    } else {
       name = toList(names)[0];
    }
    set[list[loc]] possibleParams = {params | constructor(const, params) <- p.decls};
    list[loc] params = [];
    if (isEmpty(possibleParams)) {
        params = [];
    } else {
        params = toList(possibleParams)[0];
    }
    str paramStr = "<for (param <- params, <param, \type> <- m@typeDependency) {><param.file> : <getVarType(class, param, \type)>, <}>";
    return "<getModifier(const)> <name>(<paramStr[..-2]>)";
  }
  
  str fieldString(loc class, loc field, loc \type) {
    bool isStatic = (\static() in m@modifiers[field]);
    return "<getModifier(field)> <if(isStatic){>\<u\><}><field.file><if(isStatic){>\</u\><}> : <getVarType(class, field, \type)>";
  }
  
  str methString(loc class, loc meth) {
    bool isStatic = (\static() in m@modifiers[meth]);
    bool isAbstract = (\abstract() in m@modifiers[meth]);
    str name = toList(((m@names<qualifiedName, simpleName>)[meth]))[0];
    set[list[loc]] possibleParams = {params | method(meth, params) <- p.decls};
    list[loc] params = [];
    if (isEmpty(possibleParams)) {
        params = [];
    } else {
        params = toList(possibleParams)[0];
    }
    str paramStr = "<for (param <- params, <param, \type> <- m@typeDependency) {><param.file> : <getVarType(class, param, \type)>, <}>";
    return "<getModifier(meth)> <if(isStatic){>\<u\><}><if(isAbstract){>\<i\><}><name>(<paramStr[..-2]>)<if(isAbstract){>\</i\><}><if(isStatic){>\</u\><}>";
  }
  
  rel[loc, loc] ass = {};
  rel[loc, loc] dep = {};
  
  if (\filter) {
    ass = filteredAssociations;
    dep = filteredDependencies;
  } else {
    ass = associations;
    dep = dependencies;
  }

  return "digraph classes {
         '  ratio=\"fill\"
         '  graph []
         '  fontname = \"Bitstream Vera Sans\"
         '  fontsize = 8
         '  node [ fontname = \"Bitstream Vera Sans\" fontsize = 8 shape = \"plaintext\" margin=\"0\" ]
         '  edge [ fontname = \"Bitstream Vera Sans\" fontsize = 8 ]
         '
         '  <for (cl <- classes(m)) {>
         '  <classString(cl, false)>
         '  <}>
         '  <for (cl <- interfaces(m)) {>
         '  <classString(cl, true)>
         '  <}>
         '
         '  <for (<to, from> <- extends) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"empty\"]<}>
         '  <for (<to, from> <- implements) {>
         '  \"N<to>\" -\> \"N<from>\" [style=\"dashed\", arrowhead=\"empty\"]<}>
         '  <for (<to, from> <- ass) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"vee\" headlabel=\"<multiplicity(<from, to>)>\"]<}>
         '  <for (<to, from> <- dep) {>
         '  \"N<to>\" -\> \"N<from>\" [style=\"dashed\", arrowhead=\"vee\"]<}>
         '}";
}

public void showDot(OFG g, FlowProgram p, M3 m, bool \filter) = 
        showDot(g, p, m, \filter, |home:///<m.id.authority>.dot|);
 
public void showDot(OFG g, FlowProgram p, M3 m, bool \filter, loc out) {
  writeFile(out, dotDiagram(g, p, m, \filter));
}

public void showOFG(OFG g, OFG g2) = showOFG(g, g2, |home:///OFG.dot|);

public void showOFG(OFG g, OFG g2, loc out) {
  writeFile(out, dotOFGDiagram(g, g2));
}

public void showOFG() {
    m = createM3FromEclipseProject(|project://CyberNeko1.9.21|);
    p = createOFG(|project://CyberNeko1.9.21|);
    g = buildGraph(p);
    g2 = prop(g, buildForwardGen(p), {}, true);
    g3 = prop(g, buildBackwardGen(p), {}, false);
    showOFG(g, g2 + g3);
}

public void showDot(bool \filter) {
    m = createM3FromEclipseProject(|project://CyberNeko1.9.21|);
    p = createOFG(|project://CyberNeko1.9.21|);
    g = buildGraph(p);
    g2 = prop(g, buildForwardGen(p), {}, true);
    g3 = prop(g, buildBackwardGen(p), {}, false);
    showDot(g2 + g3, p, m, \filter);
}