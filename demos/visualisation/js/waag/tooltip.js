
var tooltip=function(){
	var id = 'tt';
	var top = 3;
	var left = 3;
	var maxw = 400;
	var minw = 240;
	var speed = 10;
	var timer = 10;
	var endalpha = 85;
	var alpha = 0;
	var tt, t,c,b,h;
	var ttShow=0;
	var ie = document.all ? true : false;
	return{
		
		show:function(v, w, fixed){
			
			//check if info is equal
			if(v==info)hide();
			
			var info=v;
			if(tt == null){
				console.log("tt init");
				tt = document.createElement('div');
				tt.setAttribute('id',id);
				t = document.createElement('div');
				t.setAttribute('id',id + 'top');
				c = document.createElement('div');
				c.setAttribute('id',id + 'cont');
				b = document.createElement('div');
				b.setAttribute('id',id + 'bot');
				tt.appendChild(t);
				tt.appendChild(c);
				tt.appendChild(b);
				document.body.appendChild(tt);
				tt.style.opacity = 0;
				tt.style.filter = 'alpha(opacity=0)';
				document.onmousemove = this.pos;
			}
			ttShow++;
			
			tt.style.display = 'block';
			c.innerHTML = info;

			tt.style.width = w ? w + 'px' : 'auto';
			//console.log("w ="+tt.offsetWidth);
			
			if(!w && ie){
				t.style.display = 'none';
				b.style.display = 'none';
				tt.style.width = tt.offsetWidth;
				t.style.display = 'block';
				b.style.display = 'block';
			}
			
			//tt.style.opacity = 1;
			if(tt.offsetWidth > maxw){tt.style.width = maxw + 'px'};
			if(tt.offsetWidth < minw){tt.style.width = minw + 'px'};
			h = parseInt(tt.offsetHeight) + top;

			clearInterval(tt.timer);
			tt.timer = setInterval(function(){tooltip.fade(1)},timer);
		},
		pos:function(e){
			var u = ie ? event.clientY + document.documentElement.scrollTop : e.pageY;
			var l = ie ? event.clientX + document.documentElement.scrollLeft : e.pageX;
			
			if( (l +left + tt.offsetWidth ) > (window.innerWidth - left) ){
				tt.style.left = window.innerWidth - tt.offsetWidth - left + 'px';
			}else{
				tt.style.left = (l + left) + 'px';
			}

			if((u - h) <0){
				tt.style.top = 0 + 'px';
			}else{
				tt.style.top = (u - h) + 'px';
			}
			
			
			

		},
		fade:function(d){
			var a = alpha;
			if((a != endalpha && d == 1) || (a != 0 && d == -1)){
				var i = speed;
				if(endalpha - a < speed && d == 1){
					i = endalpha - a;
				}else if(alpha < speed && d == -1){
					i = a;
				}
				alpha = a + (i * d);
				tt.style.opacity = alpha * .01;
				tt.style.filter = 'alpha(opacity=' + alpha + ')';
			}else{
				clearInterval(tt.timer);
				if(d == -1){tt.style.display = 'none'};
			}
		},
		hide:function(){
			ttShow=0;
			if(tt==null)return;
			
			if(ttShow>0){
				//console.log("tooltip --");
				ttShow--;
			}

			if(ttShow==0){
				//console.log("hiding tooltip");
				//tt.style.opacity = 0;
				clearInterval(tt.timer);
				tt.timer = setInterval(function(){tooltip.fade(-1)},timer);
				ttShow=0;
			}

			
		}
	};
}();