module FlowGraph

import analysis::flow::ObjectFlow;
import lang::java::flow::JavaToObjectFlow;
import List;
import Relation;
import lang::java::m3::Core;

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

rel[loc, loc] buildGen(FlowProgram p)
	= { <cs + "this", cl> |
		newAssign(_, cl, cs, _) <- p.statements
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
 
public str dotDiagram(OFG g, FlowProgram p, M3 m) {

  rel[loc, loc] associations = {
    <class1, class2> |
    <class1, field> <- m@containment,
    <field, class2> <- g,
    field <- fields(m)
  };
  
  rel[loc, loc] dependencies = {
    <class1, class2> |
    <method, var> <- m@containment,
    <class1, method> <- m@containment,
    <var, class2> <- g,
    var <- variables(m) + parameters(m),
    class2 <- classes(m)
  };
    
  str classString(loc cl) {
    return "\"N<cl>\" [
    '   label = \"{<cl.path[1..]> |
    '             <for (<cl, field> <- m@containment, <field, \type> <- m@typeDependency, field <- fields(m)) {>+ <field.file> : <\type.file>\\l<}> |
    '             <for (<cl, const> <- m@containment, const <- constructors(m)) {>+ <constString(const)>\\l<}> |
        '         <for (<cl, meth> <- m@containment, meth <- methods(m), meth.scheme == "java+method") {>+ <methString(meth)>\\l<}>
    '             }\"
    ']";
  }
  
  str constString(loc const) {
    str name = toList(((m@names<qualifiedName, simpleName>)[const]))[0];
    list[loc] params = toList({params | constructor(const, params) <- p.decls})[0];
    str paramStr = "<for (param <- params, <param, \type> <- m@typeDependency) {><param.file> : <\type.file>, <}>";
    //paramStr = if (isEmpty(paramStr)) paramStr; else paramStr[..-2];
    return "<name>(<paramStr[..-2]>)";
  }
  
  str methString(loc meth) {
    str name = toList(((m@names<qualifiedName, simpleName>)[meth]))[0];
    list[loc] params = toList({params | method(const, params) <- p.decls})[0];
    str paramStr = "<for (param <- params, <param, \type> <- m@typeDependency) {><param.file> : <\type.file>, <}>";
    //paramStr = if (isEmpty(paramStr)) paramStr; else paramStr[..-2];
    return "<name>(<paramStr[..-2]>)";
  }

  return "digraph classes {
         '  graph []
         '  fontname = \"Bitstream Vera Sans\"
         '  fontsize = 8
         '  node [ fontname = \"Bitstream Vera Sans\" fontsize = 8 shape = \"record\" ]
         '  edge [ fontname = \"Bitstream Vera Sans\" fontsize = 8 ]
         '
         '  <for (cl <- classes(m)) {>
         '  <classString(cl)>
         '  <}>
         '  <for (cl <- interfaces(m)) {>
         ' \"N<cl>\" [label=\"{<cl.path[1..]>||}\"]
         '  <}>
         '
         '  <for (<to, from> <- m@extends) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"empty\"]<}>
         '  <for (<to, from> <- m@implements) {>
         '  \"N<from>\" -\> \"N<to>\" [style=\"dashed\", arrowhead=\"empty\"]<}>
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