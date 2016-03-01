module peop
import lang::java::jdt::m3::Core;
import lang::java::jdt::m3::AST;
import lang::java::flow::JavaToObjectFlow;
import analysis::flow::ObjectFlow;

M3 getM3() = createM3FromEclipseProject(|project://eLib|);
FlowProgram getFP() = createOFG(|project://eLib|);