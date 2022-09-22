import {vec2, vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;
  attrCol: number;

  unifModel: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifColor: WebGLUniformLocation;
  unifCloudColor: WebGLUniformLocation;
  unifStarColor: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifNoiseScale: WebGLUniformLocation;
  unifCoronaScale: WebGLUniformLocation;
  unifStarDensity: WebGLUniformLocation;
  unifDimensions: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.attrNor = gl.getAttribLocation(this.prog, "vs_Nor");
    this.attrCol = gl.getAttribLocation(this.prog, "vs_Col");
    this.unifModel      = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj   = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifColor      = gl.getUniformLocation(this.prog, "u_Color");
    this.unifCloudColor = gl.getUniformLocation(this.prog, "u_CloudColor");
    this.unifStarColor = gl.getUniformLocation(this.prog, "u_StarColor");
    this.unifTime      = gl.getUniformLocation(this.prog, "u_Time");
    this.unifNoiseScale = gl.getUniformLocation(this.prog, "u_NoiseScale");
    this.unifCoronaScale = gl.getUniformLocation(this.prog, "u_CoronaScale");
    this.unifStarDensity = gl.getUniformLocation(this.prog, "u_StarDensity");
    this.unifDimensions = gl.getUniformLocation(this.prog, "u_Dimensions");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
  }

  setGeometryColor(color: vec4) {
    this.use();
    if (this.unifColor !== -1) {
      gl.uniform4fv(this.unifColor, color);
    }
  }

  setCloudColor(color: vec4) {
    this.use();
    if (this.unifCloudColor !== -1) {
      gl.uniform4fv(this.unifCloudColor, color);
    }
  }

  setStarColor(color: vec4) {
    this.use();
    if (this.unifStarColor !== -1) {
      gl.uniform4fv(this.unifStarColor, color);
    }
  }

  setTime(time: number) {
    this.use();
    if (this.unifTime !== -1) {
      gl.uniform1i(this.unifTime, time);
    }
  }

  setNoiseScale(scale: number) {
    this.use();
    if (this.unifNoiseScale !== -1) {
      gl.uniform1f(this.unifNoiseScale, scale);
    }
  }

  setCoronaScale(scale: number) {
    this.use();
    if (this.unifCoronaScale !== -1) {
      gl.uniform1f(this.unifCoronaScale, scale);
    }
  }

  setStarDensity(density: number) {
    this.use();
    if (this.unifStarDensity !== -1) {
      gl.uniform1f(this.unifStarDensity, density);
    }
  }

  setDimensions(dimensions: vec2) {
    this.use();
    if (this.unifDimensions !== -1) {
      gl.uniform2fv(this.unifDimensions, dimensions);
    }
  }

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    if (this.attrNor != -1 && d.bindNor()) {
      gl.enableVertexAttribArray(this.attrNor);
      gl.vertexAttribPointer(this.attrNor, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
    if (this.attrNor != -1) gl.disableVertexAttribArray(this.attrNor);
  }
};

export default ShaderProgram;
