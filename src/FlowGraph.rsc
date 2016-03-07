module FlowGraph

import analysis::flow::ObjectFlow;
import lang::java::flow::JavaToObjectFlow;
import List;
import Relation;
import lang::java::m3::Core;
import analysis::m3::Core;
import lang::java::jdt::m3::AST;
import lang::java::jdt::m3::Core;
import lang::ofg::ast::FlowLanguage;

import IO;
import vis::Figure; 
import vis::Render;

import Set;
import String;

alias OFG = rel[loc from, loc to];

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
        assign(t, c, s) <- p.statements
      };

OFG prop(OFG g, rel[loc,loc] gen, rel[loc,loc] kill, bool back) {
  OFG IN = { };
  OFG OUT = gen + (IN - kill);
  gi = g<to,from>; // gi is relation g inverted
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


set[Decl] methodParams = {
	Decl::method(
		mfree@decl,
		[
			pfree@decl |
			pfree:parameter(t,_,_) <- params
		]
	) |
	/mfree:Declaration::method(_,_, list[Declaration] params, _, _)
		<- createAstsFromEclipseProject(|project://eLib|, true)
};

public str dotOFGDiagram(OFG g, OFG g2, OFG g3) {
  rel[loc, loc] filterG = { <from, to> | <from, to> <- g, !isEmpty(g2[to]), to.path != "/" };
  set[loc] elems = carrier(filterG);
  
  str getLabel(l) {
    list[loc] s = toList(g3[l]);
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

public str dotDiagram(OFG g, FlowProgram p, M3 m) {

  rel[loc, loc] associations = {
    <class1, class2> |
    <class1, field> <- m@containment,
    <field, class2> <- g,
    field <- fields(m)
  };
  
  rel[loc, loc] identity = { <class, class> | class <- carrier(g) };
  
  rel[loc, loc] dependencies = {
    <class1, class2> |
    <method, var> <- m@containment,
    <class1, method> <- m@containment,
    <var, class2> <- g,
    var <- variables(m) + parameters(m),
    class2 <- classes(m)
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
  
  rel[loc, loc] filteredAssociations = filterRelation(associations, m@extends + m@implements);
  
  rel[loc, loc] filteredDependencies = filterRelation(dependencies, m@extends + m@implements) - 
                                       filteredAssociations - m@extends<to, from> - identity;
    
  str classString(loc cl, bool interface) {
    return "\"N<cl>\" [
    '  label = \<\<TABLE BORDER=\"0\" ALIGN=\"LEFT\" CELLBORDER=\"1\" CELLSPACING=\"0\" CELLPADDING=\"4\"\>
    '    \<TR\>\<TD\><if(interface){>«interface»\<BR /\><}><if(\abstract() in m@modifiers[cl]){>\<i\><}><cl.path[1..]><if(\abstract() in m@modifiers[cl]){>\</i\><}>\</TD\>\</TR\>
    '    \<TR\>\<TD ALIGN=\"LEFT\" BALIGN=\"LEFT\"\><for (<cl, field> <- m@containment, <field, \type> <- m@typeDependency, field <- fields(m)) {><fieldString(field, \type)>\<BR /\><}>\</TD\>\</TR\>
    '    \<TR\>\<TD ALIGN=\"LEFT\" BALIGN=\"LEFT\"\><for (<cl, const> <- m@containment, const <- constructors(m)) {><constString(const)>\<BR /\><}><for (<cl, meth> <- m@containment, meth <- methods(m), meth.scheme == "java+method") {><methString(meth)>\<br /\><}>\</TD\>\</TR\>
    '  \</TABLE\>\>
    ']";
  }
  
  str getModifier(loc decl) {
    return if (\public() in m@modifiers[decl]) "+"; else 
           if (\private() in m@modifiers[decl]) "-"; else
           if (\protected() in m@modifiers[decl]) "#"; else "~";
  }
  
  str constString(loc const) {
    str name = toList(((m@names<qualifiedName, simpleName>)[const]))[0];
    list[loc] params = toList({params | constructor(const, params) <- p.decls})[0];
    str paramStr = "<for (param <- params, <param, \type> <- m@typeDependency) {><param.file> : <\type.file>, <}>";
    return "<getModifier(const)> <name>(<paramStr[..-2]>)";
  }
  
  str fieldString(loc field, loc \type) {
    bool isStatic = (\static() in m@modifiers[field]);
    return "<getModifier(field)> <if(isStatic){>\<u\><}><field.file><if(isStatic){>\</u\><}> : <\type.file>";
  }
  
  str methString(loc meth) {
    bool isStatic = (\static() in m@modifiers[meth]);
    bool isAbstract = (\abstract() in m@modifiers[meth]);
    str name = toList(((m@names<qualifiedName, simpleName>)[meth]))[0];
    rel[loc, TypeSymbol] paramTypes =
    {
		<param, paramType> |
		param <- m@containment[meth],
		param.scheme == "java+parameter",
		paramType <- m@types[param]
	};
	list[tuple[loc, TypeSymbol]] params =
	[
		<paramLoc, paramType> |
		method(meth, paramLocs) <- methodParams,
		paramLoc <- paramLocs,
		paramType <- paramTypes[paramLoc]
	];
    print (params);
    print("\n");
    str paramStr = "<for (<param, \type> <- params) {><param.file> : <\type>, <}>";
    return "<getModifier(meth)> <if(isStatic){>\<u\><}><if(isAbstract){>\<i\><}><name>(<paramStr[..-2]>)<if(isAbstract){>\</i\><}><if(isStatic){>\</u\><}>";
  }

  return "digraph classes {
         '  ratio=\"fill\"
         '  graph [splines = \"ortho\"]
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
         '  <for (<to, from> <- m@extends) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"empty\"]<}>
         '  <for (<to, from> <- m@implements) {>
         '  \"N<to>\" -\> \"N<from>\" [style=\"dashed\", arrowhead=\"empty\"]<}>
         '  <for (<to, from> <- associations) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"vee\"]<}>
         '  <for (<to, from> <- dependencies) {>
         '  \"N<to>\" -\> \"N<from>\" [style=\"dashed\", arrowhead=\"vee\"]<}>
         '}";
}

public void showDot(OFG g, FlowProgram p, M3 m) = showDot(g, p, m, |home:///<m.id.authority>.dot|);
 
public void showDot(OFG g, FlowProgram p, M3 m, loc out) {
  writeFile(out, dotDiagram(g, p, m));
}

public void showOFG(OFG g, OFG g2, OFG g3) = showOFG(g, g2, g3, |home:///OFG.dot|);

public void showOFG(OFG g, OFG g2, OFG g3, loc out) {
  writeFile(out, dotOFGDiagram(g, g2, g3));
}

public void showOFG() {
    m = createM3FromEclipseProject(|project://eLib|);
    p = createOFG(|project://eLib|);
    g = buildGraph(p);
    g2 = prop(g, buildForwardGen(p), {}, true);
    g3 = prop(g, buildBackwardGen(p), {}, false);
    showOFG(g, g2, g3);
}

public void showDot() {
    m = createM3FromEclipseProject(|project://eLib|);
    p = createOFG(|project://eLib|);
    g = buildGraph(p);
    g2 = prop(g, buildForwardGen(p), {}, true);
    showDot(g2, p, m);
}