module FlowGraph

import analysis::flow::ObjectFlow;
import lang::java::flow::JavaToObjectFlow;
import List;
import Relation;
import lang::java::m3::Core;

import IO;
import vis::Figure; 
import vis::Render;

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

public void drawDiagram(M3 m) {
  classFigures = [box(text("<cl.path[1..]>"), id("<cl>")) | cl <- classes(m)]; 
  edges = [edge("<to>", "<from>") | <from,to> <- m@extends ];  
  
  render(graph(classFigures, edges, hint("layered"), std(gap(10)), std(font("Bitstream Vera Sans")), std(fontSize(8))));
}

public void drawDiagram(OFG p, M3 m) {
  rel[loc, loc, loc] associations = {
  	<field, class1, class2> |
  	<class1, field> <- m@containment,
  	<field, class2> <- p,
  	field <- fields(m)
  };
  
  rel[loc, loc, loc] dependencies = {
  	<var, class1, class2> |
 	<method, var> <- m@containment,
 	<class1, method> <- m@containment,
  	<var, class2> <- p,
  	var <- variables(m)+parameters(m),
  	class2 <- classes(m)
  };
  
  classFigures = [box(text("<cl.path[1..]>"), id("<cl>")) | cl <- classes(m)]; 
  generalisationEdges
  	= [edge("<to>", "<from>") | <from,to> <- m@extends ];  
  realisationEdges
  	= [edge("<to>", "<from>") | <from,to> <- m@implements ];  
  associationEdges
  	= [edge("<to>", "<from>") | <_,from,to> <- associations ];
  dependencyEdges
  	= [edge("<to>", "<from>") | <_,from,to> <- dependencies ];
  
  render(graph(
  	classFigures,
  	dependencyEdges,
  	hint("layered"),
  	std(gap(10)),
  	std(font("Bitstream Vera Sans")),
  	std(fontSize(8))
  ));
}
 
public str dotDiagram(M3 m) {
  return "digraph classes {
         '  fontname = \"Bitstream Vera Sans\"
         '  fontsize = 8
         '  node [ fontname = \"Bitstream Vera Sans\" fontsize = 8 shape = \"record\" ]
         '  edge [ fontname = \"Bitstream Vera Sans\" fontsize = 8 ]
         '
         '  <for (cl <- classes(m)) { /* a for loop in a string template, just like PHP */>
         ' \"N<cl>\" [label=\"{<cl.path[1..] /* a Rascal expression between < > brackets is spliced into the string */>||}\"]
         '  <} /* this is the end of the for loop */>
         '
         '  <for (<from, to> <- m@extends) {>
         '  \"N<to>\" -\> \"N<from>\" [arrowhead=\"empty\"]<}>
         '}";
}
 
public void showDot(M3 m) = showDot(m, |home:///<m.id.authority>.dot|);
 
public void showDot(M3 m, loc out) {
  writeFile(out, dotDiagram(m));
}