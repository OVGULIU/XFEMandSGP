function C =  materialstiffness(stress,eplas,dep,dstrain,materialprops)
   
%  Bulk modulus, Youngs modulus and Poissons ratio
   K = materialprops(1)/(3*(1-2*materialprops(2)));
   E = materialprops(1);
   nu = materialprops(2);
   e0 = materialprops(4);
   n = materialprops(5);
   m = materialprops(7);
   
%
%  S is the current approx for deviatoric stress at end of increment
%
   S = zeros(3,3);
   de = zeros(3,3);
   dl = [ [1,0,0];[0,1,0];[0,0,1] ]; 

   devol = trace(dstrain);
   p = trace(stress);
   
   se = 0;
   for i = 1 : 3
     for j = 1 : 3
        de(i,j) = dstrain(i,j) - dl(i,j)*devol/3;
        S(i,j) = stress(i,j) - dl(i,j)*p/3;
        se = se + S(i,j)*S(i,j);
     end
   end
   se = sqrt(1.5*se);

   if (se*dep>0)
     beta = 1./(1+1.5*E*dep/((1+nu)*se));
     gamma = beta*( 1.5*E/((1+nu)*se)+(1/(n*(e0+eplas+dep))+1/(m*dep)) );
     factor = 1.5*1.5*E*(dep-1/gamma)/((1+nu)*se^3);
   else
     beta = 1.;   
     factor = 0.;
   end      
     for i = 1 : 2
       for j = 1 : 2
         for k = 1 : 2
           for l = 1 : 2
             C(i,j,k,l) = beta*E/(1+nu)*((dl(i,k)*dl(j,l)+dl(j,k)*dl(i,l))/2-dl(i,j)*dl(k,l)/3 ...
                                   + factor*S(i,j)*S(k,l)) + K*dl(i,j)*dl(k,l);
           end
         end
       end
     end
end