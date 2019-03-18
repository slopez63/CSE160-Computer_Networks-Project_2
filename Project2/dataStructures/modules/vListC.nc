/**
 * ANDES Lab - University of California, Merced
 * This class provides a simple nList.
 *
 * @author UCM ANDES Lab
 * @author Alex Beltran
 * @date   2013/09/03
 *
 */

generic module vListC(typedef t, int n){
	provides interface vList<t>;
}

implementation{
	uint16_t MAX_SIZE = n;

	t container[n];
	uint16_t size = 0;

	command void vList.pushback(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
		}
	}

	command void vList.pushfront(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			int32_t i;
			// Shift everything to the right.
			for(i = size-1; i>=0; i--){
				container[i+1] = container[i];
			}

			container[0] = input;
			size++;
		}
	}

	command t vList.popback(){
		t returnVal;

		returnVal = container[size];
		// We don't need to actually remove the value, we just need to decrement
		// the size.
		if(size > 0)size--;
		return returnVal;
	}

	command t vList.popfront(){
		t returnVal;
		uint16_t i;

		returnVal = container[0];
		if(size>0){
			// Move everything to the left.
			for(i = 0; i<size-1; i++){
				container[i] = container[i+1];
			}
			size--;
		}

		return returnVal;
	}

	// This is similar to peek head.
	command t vList.front(){
		return container[0];
	}

	// Peek tail
	command t vList.back(){
		return container[size-1];
	}

	command bool vList.isEmpty(){
		if(size == 0)
			return TRUE;
		else
			return FALSE;
	}

	command uint16_t vList.size(){
		return size;
	}

	command t vList.get(uint16_t position){
		return container[position];
	}
}
